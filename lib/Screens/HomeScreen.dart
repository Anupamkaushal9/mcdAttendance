import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math'as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Helpers/Constant.dart';
import 'package:mcd_attendance/Screens/InAttendanceNewUI.dart';
import 'package:mcd_attendance/Screens/InAttendanceScreen.dart';
import 'package:mcd_attendance/Utils/fake_location_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/String.dart';
import '../Model/Employee.dart';
import '../Model/EmployeeHistoryModel.dart';
import '../Model/OrganizationDataModel.dart';
import 'Widgets/DialogBox.dart';

class HomeScreen extends StatefulWidget {
  final String bmid;
  final List<EmpData> employee;
  //final List<EmpHistoryData>? empHistoryData;
  final String inTime;
  final String outTime;
  final int day;

  const HomeScreen({
    Key? key,
    required this.bmid,
    required this.employee,
    //this.empHistoryData,
    required this.day, required this.inTime, required this.outTime,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Formatters
  static final _resultFormatter = DateFormat('EEEE, MMM dd');
  static final _timeFormatter = DateFormat('HH:mm:ss');
  static final _displayTimeFormatter = DateFormat('hh:mm a');
  static final _dayFormatter = DateFormat('d');

  // State variables
  String _timeString = '';
  String resultDate = '';
  String clockInValue = '-';
  String clockOutValue = '-';
  String workingHrValue = '00:00:00';
  String dayVal = '';

  // Timers and animations
  Timer? _workingHoursTimer;
  Timer? _realTimeTimer;
  bool isLoading = true;
  bool _isDataReady = false; // New flag to track if data is fully loaded

  // API and data
  final ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<OrgData> orgData = [];
  bool showLoader = true;
  bool isContainFaceData = false;

  // Cached values
  DateTime? _cachedInTime;
  DateTime? _cachedOutTime;
  String? _cachedClockInFormatted;
  String? _cachedDayVal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _showNoInternetDialog();
        return;
      }

      final now = DateTime.now();
      resultDate = _resultFormatter.format(now);
      _timeString = _formatDateTime(now);

      await Future.wait([
        getOrgList(),
        getEmpFaceData(),
      ]);
      await _loadInitialData();

      Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (mounted) {
          setState(() => _timeString = _formatDateTime(DateTime.now()));
        }
      });
      // Mark data as ready after everything is loaded
      if (mounted) {
        setState(() {
          _isDataReady = true;
          isLoading = false;
        });
      }
    } catch (e) {
      _showNullValueError("Initialization error: ${e.toString()}");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: NoInternetDialog(
            onRetry: () {
              Navigator.of(context).pop();
              if (Platform.isAndroid) {
                FlutterExitApp.exitApp();
              } else {
                FlutterExitApp.exitApp(iosForceExit: true);
              }
            },
          ),
        );
      },
    );
  }

  Future<void> getEmpFaceData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final parameter = {"bmid": widget.bmid};
      final getData = await apiBaseHelper.postAPICall(
        Uri.parse('${baseUrl}emp-face-data'),
        parameter,
      );

      if (!mounted) return;

      if (getData['status']?.toString() == 'TRUE') {
        final data = getData['msg'];
        final efmImg = data['efm_img'] ?? '';
        await saveUserFaceData(efmImg);
      }
    } catch (e) {
      if (mounted) {
        //_showNullValueError("getEmpFaceData error: ${e.toString()}");
        debugPrint("getEmpFaceData error: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> saveUserFaceData(String userFaceData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_face_data', userFaceData);
  }

  Future<void> _setOrgBasicGuidSharedPref(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('orgUnitBasicGuid', value);

    if (mounted) {
      setState(() => orgUnitBasicGuid = prefs.getString('orgUnitBasicGuid') ?? '');
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      await Future.wait([
        getLastAttendance(),
        if (orgData.isEmpty) getOrgList(),
      ]);

      if (mounted) {
        _initializeTimers();
        updateWorkingHours();
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _initializeTimers() {
    _workingHoursTimer?.cancel();
    _realTimeTimer?.cancel();

    if (!mounted) return;

    _workingHoursTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      updateWorkingHours();
    });

    if (outTiming.isEmpty) {
      _realTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (inTiming.isNotEmpty) {
          final now = DateTime.now();
          final inTime = _cachedInTime ?? DateTime.parse(inTiming);
          if (mounted) {
            setState(() {
              workingHrValue = _formatDuration(now.difference(inTime));
            });
          }
        }
      });
    }
  }

  Future<void> getOrgList() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final parameter = {
        "appCode": "org.dmc.smartcity",
        "loginId": widget.bmid,
      };

      final getData = await apiBaseHelper.postAPICall(OrgListApi, parameter);
      final jsonData = getData is String ? json.decode(getData) : getData;

      if (!mounted) return;

      if (jsonData['status']?.toString() == 'TRUE') {
        final orgList = jsonData['orgList'];
        if (orgList != null && orgList['org'] != null) {
          final organizations = orgList['org'];
          if (organizations is List) {
            final mappedOrgData = organizations.map<OrgData>((org) {
              return OrgData.fromJson(org);
            }).toList();

            if (mounted) {
              setState(() {
                orgData = mappedOrgData;
                if (orgData.isNotEmpty) {
                  _setOrgBasicGuidSharedPref(orgData.first.orgUnitBasicGuid);
                }
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showNullValueError("getOrgList error: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _formatDuration(Duration duration) {
    return "${duration.inHours.toString().padLeft(2, '0')}:"
        "${(duration.inMinutes % 60).toString().padLeft(2, '0')}:"
        "${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  void _showNullValueError(String errorDetails) {
    if (mounted) {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (_) => WillPopScope(
          onWillPop: () async => false,
          child: SomethingWentWrongDialog(errorDetails: errorDetails),
        ),
      );
    }
  }

  Future<void> saveFaceAndSupervisorData(
      bool isSupervisor,
      bool hasFaceData,
      bool isContainData1,
      bool isContainData2,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setBool('supervisor_access', isSupervisor);
      await prefs.setBool('available_face_data', hasFaceData);
      await prefs.setBool('available_data_1', isContainData1);
      await prefs.setBool('available_data_2', isContainData2);

      hasSuperVisorAccess = prefs.getBool('supervisor_access') ?? false;
      faceDataAvailableFromApi = prefs.getBool('available_face_data') ?? false;
      isContainDataOne = prefs.getBool('available_data_1') ?? false;
      isContainDataTwo = prefs.getBool('available_data_2') ?? false;

      if (!hasFaceData) {
        await prefs.setString('user_face_data', '');
      }
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }

  Future<void> getLastAttendance() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final parameter = {"empGuid": empGuid};
      final getData = await apiBaseHelper.postAPICall(lastAttendanceApi, parameter);

      if (!mounted) return;

      final error = getData['error']?.toString() ?? '';
      final status = getData['status']?.toString() ?? '';

      if (status == 'TRUE') {
        final inTime = getData['in_time']?.toString() ?? '';
        final outTime = getData['out_time']?.toString() ?? '';
        final isSupervisor = getData['is_supervisor'] ?? false;
        final hasFaceData = getData['has_face_data'] ?? false;
        final hasData1 = getData['has_data_01'] ?? false;
        final hasData2 = getData['has_data_02'] ?? false;

        await saveFaceAndSupervisorData(isSupervisor, hasFaceData, hasData1, hasData2);
        isContainFaceData = hasFaceData;

        final now = DateTime.now();
        if (inTime.isNotEmpty && outTime.isNotEmpty) {
          final inDateTime = DateTime.parse(inTime);
          if (inDateTime.year != now.year ||
              inDateTime.month != now.month ||
              inDateTime.day != now.day) {
            inTiming = '';
            outTiming = '';
          } else {
            inTiming = inTime;
            outTiming = outTime;
          }
        } else if (inTime.isNotEmpty && outTime.isEmpty) {
          final inDateTime = DateTime.parse(inTime);
          if (now.difference(inDateTime).inHours >= 20) {
            inTiming = '';
            outTiming = '';
          } else {
            inTiming = inTime;
            outTiming = outTime;
          }
        } else {
          inTiming = '';
          outTiming = '';
        }
      } else if (error == 'NO RECORD FOUND.' && !isFreshUser) {
        await _clearPreference();
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => WillPopScope(
              onWillPop: () async => false,
              child: SomethingWentWrongDialog(errorDetails: error),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showNullValueError("getLastAttendance error: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void updateWorkingHours() {
    if (!mounted) return;
    setState(() => isLoading = true);

    if (inTiming.isEmpty) {
      if (mounted) {
        setState(() {
          clockInValue = '-';
          clockOutValue = '-';
          workingHrValue = '00:00:00';
          dayVal = '';
          isLoading = false;
        });
      }
      return;
    }

    _cachedInTime ??= DateTime.parse(inTiming);
    final inTime = _cachedInTime!;
    _cachedClockInFormatted ??= _displayTimeFormatter.format(inTime);
    _cachedDayVal ??= _dayFormatter.format(inTime);

    String workingHr;
    String clockOutFormatted;

    if (outTiming.isNotEmpty) {
      _cachedOutTime ??= DateTime.parse(outTiming);
      final outTime = _cachedOutTime!;
      clockOutFormatted = _displayTimeFormatter.format(outTime);
      workingHr = _formatDuration(outTime.difference(inTime));
    } else {
      clockOutFormatted = '-';
      workingHr = _formatDuration(DateTime.now().difference(inTime));
    }

    if (mounted) {
      setState(() {
        clockInValue = _cachedClockInFormatted!;
        clockOutValue = clockOutFormatted;
        workingHrValue = workingHr;
        dayVal = _cachedDayVal!;
        isLoading = false;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return _timeFormatter.format(dateTime);
  }

  Future<void> _clearPreference() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
  }

  @override
  void dispose() {
    _workingHoursTimer?.cancel();
    _realTimeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) {
      return const SizedBox.shrink();
    }

    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: Stack( // Use Stack to overlay elements
        children: [
          // Left side Lottie animation
          Visibility(visible: (event=='Independence Day'||event=='Republic Day'),
            child: Positioned(
              left: -80.w, // Adjust this value to control how much is visible
              top: 50,
              bottom: 0,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.9, // Adjust opacity as needed
                  child: Lottie.asset(
                    'assets/animations/indian_flag.json', // Your left animation
                    width: 200.w,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // Right side Lottie animation
          Visibility(visible: (event=='Independence Day'||event=='Republic Day'),
            child: Positioned(
              right: -80.w,
              top: 50,
              bottom: 0,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.9,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi), // Rotate 180 degrees
                    child: Lottie.asset(
                      'assets/animations/indian_flag.json', // Same animation file
                      width: 200.w,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),

          isLoading || !_isDataReady
              ? Center(
            child: Lottie.asset(
              'assets/animations/loading_animation.json',
              height: 50.h,
              width: 50.w,
            ),
          )
              : ListView(
            padding: const EdgeInsets.all(5),
            children: [
              SizedBox(height: 10.h,),
              Center(
                child: Text(
                  resultDate,
                  style: TextStyle(
                    fontSize: 25.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Center(
                child: Text(
                  "Working Hours",
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
              ),
              Center(
                child: Text(
                  workingHrValue,
                  style: TextStyle(
                    fontSize: 50.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
              ),
              SizedBox(height: 30.h,),
              SizedBox(
                child: Row(
                  children: [
                    _buildTimeColumn(
                      icon: 'assets/images/clock-rotate-left-icon.svg',
                      time: clockInValue,
                      label: 'In Time',
                    ),
                    _buildTimeColumn(
                      icon: 'assets/images/clock-rotate-right-icon.svg',
                      time: clockOutValue,
                      label: 'Out Time',
                    ),
                  ],
                ),
              ),
              if (outTiming.isEmpty) SizedBox(height: height / 10),
              if (outTiming.isEmpty)
                _buildClockInOutButton(height, width),
              if (outTiming.isNotEmpty)
                _buildAttendanceCompleteView(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn({
    required String icon,
    required String time,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          SvgPicture.asset(icon, height: 30.h),
          SizedBox(height: 10.h),
          Text(
            time,
            style: TextStyle(
              color: Colors.black,
              fontSize: 25.0.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildClockInOutButton(double height, double width) {
    return SizedBox(
      height: height / 4,
      child: GestureDetector(
        onTap: () {
          // Skip mock location check for iOS
          if (!Platform.isIOS) {
            checkForMockLocation(context);
          }
          if (faceDataAvailableFromApi && isContainDataOne && isContainDataTwo) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InAttendanceScreen(
                 // empHistoryData: widget.empHistoryData,
                  inTime: inTiming,
                  outTime:outTiming,
                  employee: widget.employee,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InAttendanceNewUiScreen(
                  //empHistoryData: widget.empHistoryData,
                  inTime: inTiming,
                  outTime:outTiming,
                  employee: widget.employee,
                ),
              ),
            );
          }
        },
        child: Column(
          children: [
            Expanded(
              child: Container(
                height: 220.h,
                width: 220.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _getButtonGradient(),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade600,
                      spreadRadius: 1,
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Lottie.asset(
                      'assets/animations/hand_click_animation.json',
                      height: 160.h,
                      width: 160.w,
                    ),
                    Text(
                      _getButtonText(),
                      textScaleFactor: (width > 500) ? 0.8 : 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (height < 600) ? 20.0.sp : 25.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Gradient _getButtonGradient() {
    if (inTiming.isEmpty && outTiming.isEmpty) {
      return const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Colors.greenAccent, Colors.lightGreen],
      );
    } else if (inTiming.isNotEmpty && outTiming.isEmpty) {
      return const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Colors.redAccent, Color(0xFFFFCDD2)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Colors.grey, Colors.grey],
    );
  }

  String _getButtonText() {
    if (inTiming.isEmpty && outTiming.isEmpty) {
      return 'Clock In';
    } else if (inTiming.isNotEmpty && outTiming.isEmpty) {
      return 'Clock Out';
    }
    return '';
  }

  Widget _buildAttendanceCompleteView() {
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Lottie.asset(
                'assets/animations/celebration.json',
                repeat: false,
              ),
              Column(
                children: [
                  Text(
                    'Thank you!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 18.sp,
                    ),
                  ),
                  Text(
                    "Today's Attendance Done \n Please Check Tomorrow",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                      fontSize: 18.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}