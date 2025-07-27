import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:animated_digit/animated_digit.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Model/SupervisorEmployeeModel.dart';
import 'package:mcd_attendance/Screens/InAttendanceNewUIForSupervisor.dart';
import 'package:mcd_attendance/Screens/InAttendanceScreenForSupervisor.dart';
import 'package:mcd_attendance/Utils/fake_location_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/Constant.dart';
import '../Helpers/String.dart';
import '../Model/EmployeeHistoryModel.dart';
import '../Model/OrganizationDataModel.dart';
import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class HomeSupervisorScreen extends StatefulWidget {
  final String guid;
  final String bmid;
  List<EmpHistoryData>? empHistoryData = [];
  List<SupervisorEmployeeModel>? employeeInfoList ;
  final int day;

  HomeSupervisorScreen({
    super.key,
    required this.guid,
    required this.bmid,
    this.empHistoryData,
    required this.day,
    this.employeeInfoList
  });

  @override
  State<HomeSupervisorScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeSupervisorScreen>
    with WidgetsBindingObserver {
  // Formatters - initialize once
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

  // Timers
  Timer? _workingHoursTimer;
  Timer? _realTimeTimer;

  // Animation control
  bool isLoading = true;
  bool isAnimating = true;
  final Random _random = Random();
  int? animatedHours;
  int? animatedMinutes;
  int? animatedSeconds;

  // API and data
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<OrgData> orgData = [];
  bool showLoader = true;
  List<EmpHistoryData>? empHistoryData = [];

  // Cached values
  DateTime? _cachedInTime;
  DateTime? _cachedOutTime;
  String? _cachedClockInFormatted;
  String? _cachedDayVal;
  bool isContainFaceData = false;
  bool hasDataOne = false;
  bool hasDataTwo = false;

  @override
  void initState() {
    super.initState();
    _checkInternetAndInitialize();
  }

  Future<void> _checkInternetAndInitialize() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return NoInternetDialog(
            onRetry: () {
              (Platform.isAndroid)?FlutterExitApp.exitApp():FlutterExitApp.exitApp(iosForceExit: true);
            },
          );
        },
      );
      return;
    }
    WidgetsBinding.instance.addObserver(this);

    // Initialize date and time
    final now = DateTime.now();
    resultDate = _resultFormatter.format(now);
    _timeString = _formatDateTime(now);
    await getOrgList();
    await getEmpFaceData();
    // Start animation and load data
    startAnimationTimer();
    _loadInitialData();


    // Setup timers
    Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
  }

  Future<void> getEmpFaceData() async {
    setState(() {
      isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    var parameter = {
      "bmid": widget.bmid,
    };

    try {
      var getData = await apiBaseHelper.postAPICall(
        Uri.parse('${baseUrl}emp-face-data'),
        parameter,
      );

      print("API Response: $getData");

      String status = getData['status']?.toString() ?? '';
      String errorMsg = getData['error']?.toString() ?? 'Unknown error';

      if (status == 'TRUE') {
        var data = getData['msg'];

        String efmImg = data['efm_img'] ?? '';
        String efmPath = data['efm_path'] ?? '';
        String remarks = data['efm_remarks'] ?? 'No remarks';

        saveUserFaceData(efmImg);

        print('Super user Base64 Image: $efmImg');
        print('Super user Image Path: $efmPath');

      } else {
       // _showNullValueError("getEmpFaceData Api Error: $errorMsg $status");
      }
    } catch (e) {
      _showNullValueError("getEmpFaceData Api Error: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  saveUserFaceData(String userFaceData) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('super_user_face_data', userFaceData);
  }

  Future<void> _setOrgBasicGuidSharedPref(String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('orgUnitBasicGuidForSuper', value!);

    if (mounted) {
      setState(() {
        orgUnitBasicGuidForSuper = prefs.getString('orgUnitBasicGuidForSuper')!;
      });
    }
    print('orgUnitBasicGuid = $orgUnitBasicGuidForSuper');
  }

  Future<void> _loadInitialData() async {
    if (mounted) {
      setState(() {
        isLoading = true;  // Start loading indicator
      });
    }

    try {
      await getEmpHistory();
      await getLastAttendance();

      if (mounted) {
        _initializeTimers();
        updateWorkingHours();
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false; // Stop loading indicator when all done
        });
      }
    }
  }


  void startAnimationTimer() {
    Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (isAnimating && mounted) {
        setState(() {
          animatedHours = _random.nextInt(24);
          animatedMinutes = _random.nextInt(60);
          animatedSeconds = _random.nextInt(60);
        });
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => isAnimating = false);
      }
    });
  }

  void _initializeTimers() {
    // Update working hours every minute
    _workingHoursTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      updateWorkingHours();
    });

    // Real-time update only if clocked in but not out
    if (outTimingForSuper.isEmpty) {
      _realTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && inTimingForSuper.isNotEmpty) {
          final now = DateTime.now();
          final inTime = _cachedInTime ?? DateTime.parse(inTimingForSuper);
          setState(() {
            workingHrValue = _formatDuration(now.difference(inTime));
          });
        }
      });
    }
  }

  Future<void> getOrgList() async {
    setState(() {
      isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    var parameter = {
      "appCode": "org.dmc.smartcity",
      "loginId": widget.bmid,
    };

    try {
      var getData = await apiBaseHelper.postAPICall(OrgListApi, parameter);

      if (getData is String) {
        getData = json.decode(getData);
      }

      String status = getData['status']?.toString() ?? '';
      print("API Response: $getData");

      if (status == 'TRUE') {
        var orgList = getData['orgList'];
        var orgBasicGuid;

        if (orgList != null && orgList['org'] != null) {
          var organizations = orgList['org'];

          if (organizations is List) {
            final List<OrgData> mappedOrgData = organizations.map<OrgData>((org) {
              if (org is Map<String, dynamic>) {
                return OrgData.fromJson(org);
              } else {
                throw Exception('Invalid data format in org list');
              }
            }).toList();

            if (mounted) {
              setState(() {
                orgData = mappedOrgData;
                isLoading = false;

                // Optionally print each org
                for (var org in orgData) {
                  print('Org Code: ${org.code}');
                  print('Org Name: ${org.name}');
                  print('Org GUID: ${org.orgGuid}');
                  print('Designation GUID: ${org.designationGuid}');
                  print('Designation Name: ${org.designationName}');
                  print('Org Unit Basic GUID: ${org.orgUnitBasicGuid}');
                  print('-------------------------------');
                }

                orgBasicGuid = orgData.first.orgUnitBasicGuid;
                _setOrgBasicGuidSharedPref(orgBasicGuid);
              });
            }
          } else {
            _showNullValueError("getOrgList Api Expected a list of organizations, but got: $organizations");
          }
        } else {
          _showNullValueError("getOrgList Api Organization data is missing.");
        }
      } else {
        _showNullValueError("getOrgList Api Failed to fetch organization list: ${getData['error']+ status ?? 'Unknown error'}");
      }
    } catch (e) {
      _showNullValueError("getOrgList Api Error occurred: ${e.toString()}");
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


  getEmpHistory() async {
    print("Layout History is running");
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "orgUnitGuid": "2493c2cd-5510-451d-9afe-e1a1468d0ac2",
      "month": DateTime.now().month,
      "year": DateTime.now().year,
      "empGuid": widget.guid
    };

    try {
      await apiBaseHelper.postAPICall(getEmpHistoryApi, parameter).then(
              (getData) {
            // Check for null response
            if (getData == null) {
              _showNullValueError("API returned null response....getHistory API");
              return;
            }

            String error = getData['error'].toString();
            String? msg = getData['status'].toString();

            if (msg == 'TRUE') {
              // Check if attendanceXML exists
              if (!getData.containsKey('attendanceXML')) {
                _showNullValueError("getEmpHistory Api Missing attendance data in API response....getHistory API");
                return;
              }

              var attendanceXML = getData['attendanceXML'];
              // Check if attendanceList exists
              if (attendanceXML == null || !attendanceXML.containsKey('attendanceList')) {
                _showNullValueError("getEmpHistory Api Missing attendance list in API response....getHistory API");
                return;
              }

              var data = attendanceXML['attendanceList'];
              if (mounted) {
                setState(() {
                  try {
                    empHistoryData = data
                        .map<EmpHistoryData>((json) => EmpHistoryData.fromJson(json))
                        .toList();
                    isFreshUserForSupervisor = empHistoryData == null || empHistoryData!.isEmpty;
                    print('historyDataForSuper =${empHistoryData![0].inTime!}');
                    isLoading = false;
                  } catch (e) {
                    _showNullValueError("getEmpHistory Api Error parsing attendance data: ${e.toString()}....getHistory API");
                    empHistoryData = [];
                    isLoading = false;
                  }
                });
              }
            } else {
              print(error+msg);
              if(!error.contains("NO RECORD FOUND."))
                {
                  _showNullValueError("getEmpHistory Api : $error $msg");
                }
              isLoading = false;
            }
          },
          onError: (e) {
            _showNullValueError('getEmpHistory Api : $e');
          }
      );
    } catch (e) {
      _showNullValueError("getEmpHistory Api : $e");
    }
  }

  Future<void> getLastAttendance() async {
    if (mounted) {
      setState(() {
        isLoading = true;  // Show loader before starting API call
      });
    }

    try {
      final parameter = {"empGuid": widget.guid};
      final getData = await apiBaseHelper.postAPICall(lastAttendanceApi, parameter);

      if (!mounted) return;

      final error = getData['error']?.toString() ?? '';
      final status = getData['status']?.toString() ?? '';

      if (status == 'TRUE') {
        final inTime = getData['in_time']?.toString() ?? '';
        final outTime = getData['out_time']?.toString() ?? '';
        isContainFaceData = getData['has_face_data'];
        hasDataOne = getData['has_data_01'] ?? false;
        hasDataTwo = getData['has_data_02'] ?? false;
        final now = DateTime.now();

        if (inTime.isNotEmpty && outTime.isNotEmpty) {
          final inDateTime = DateTime.parse(inTime);
          if (inDateTime.year != now.year ||
              inDateTime.month != now.month ||
              inDateTime.day != now.day) {
            inTimingForSuper = '';
            outTimingForSuper = '';
          } else {
            inTimingForSuper = inTime;
            outTimingForSuper = outTime;
          }
        } else if (inTime.isNotEmpty && outTime.isEmpty) {
          final inDateTime = DateTime.parse(inTime);
          if (now.difference(inDateTime).inHours >= 20) {
            inTimingForSuper = '';
            outTimingForSuper = '';
          } else {
            inTimingForSuper = inTime;
            outTimingForSuper = outTime;
          }
        } else {
          inTimingForSuper = '';
          outTimingForSuper = '';
        }
      } else if (error == 'NO RECORD FOUND.') {
        if (mounted && !isFreshUserForSupervisor) {
          await _clearPreference();
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
        _showNullValueError("getLastAttendance Api : $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;  // Hide loader once done (success or failure)
        });
      }
    }
  }


  void updateWorkingHours() {
    if (mounted) {
      setState(() {
        isLoading = true;  // Show loader at start
      });
    }

    if (inTimingForSuper.isEmpty) {
      if (mounted) {
        setState(() {
          clockInValue = '-';
          clockOutValue = '-';
          workingHrValue = '00:00:00';
          dayVal = '';
          isLoading = false;  // Hide loader since we're done
        });
      }
      return;
    }

    // Parse and cache DateTime objects
    _cachedInTime ??= DateTime.parse(inTimingForSuper);
    final inTime = _cachedInTime!;

    // Format clock in time (cache if not already cached)
    _cachedClockInFormatted ??= _displayTimeFormatter.format(inTime);
    _cachedDayVal ??= _dayFormatter.format(inTime);

    String workingHr;
    String clockOutFormatted;

    if (outTimingForSuper.isNotEmpty) {
      _cachedOutTime ??= DateTime.parse(outTimingForSuper);
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
        isLoading = false;  // Hide loader after updating state
      });
    }
  }


  String _formatDateTime(DateTime dateTime) {
    return _timeFormatter.format(dateTime);
  }

  void _getTime() {
    if (mounted) {
      setState(() {
        _timeString = _formatDateTime(DateTime.now());
      });
    }
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
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'MCD PRO', isLayoutScreen: false),
      body: isLoading
          ? Center(
        child: Lottie.asset(
          'assets/animations/loading_animation.json',
          height: 50.h,
          width: 50.w,
        ),
      )
          : Padding(
        padding:  EdgeInsets.only(left: 8.0,right: 8.0,bottom: 8.0,top: kToolbarHeight+ MediaQuery.of(context).padding.top),
            child: ListView(
                    padding: const EdgeInsets.all(5),
                    children: [
                      SizedBox(height: 20.h),
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
                      SizedBox(height: 30.h),
            SizedBox(
              child: Column(
                children: [
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
                ],
              ),
            ),
            SizedBox(height: 30.h,),
            SizedBox(
              height: height / 6.5,
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
            if (outTimingForSuper.isEmpty) SizedBox(height: height / 20),
            if (outTimingForSuper.isEmpty)
              _buildClockInOutButton(height),
            if (outTimingForSuper.isNotEmpty)
              _buildAttendanceCompleteView(),
                    ],
                  ),
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

  Widget _buildClockInOutButton(double height) {
    return SizedBox(
      height: height / 4,
      child: GestureDetector(
        onTap: () {
          // Skip mock location check for iOS
          if (!Platform.isIOS) {
            checkForMockLocation(context);
          }
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (_) => InAttendanceNewUiForSupervisorScreen(
          //       empHistoryData: widget.empHistoryData,
          //       bmid: widget.bmid,
          //       guid: widget.guid, employeeInfoList: widget.employeeInfoList??[],
          //     ),
          //   ),
          // );
          (isContainFaceData&&hasDataOne&&hasDataTwo)?Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InAttendanceForSupervisorScreen(
                guid:widget.guid,
                //empHistoryData: widget.empHistoryData,
              ),
            ),
          ):Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InAttendanceNewUiForSupervisorScreen(
                //empHistoryData: widget.empHistoryData,
                      bmid: widget.bmid,
                      guid: widget.guid, employeeInfoList: widget.employeeInfoList??[],
              ),
            ),
          );
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
    if (inTimingForSuper.isEmpty && outTimingForSuper.isEmpty) {
      return const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Colors.greenAccent, Colors.lightGreen],
      );
    } else if (inTimingForSuper.isNotEmpty && outTimingForSuper.isEmpty) {
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
    if (inTimingForSuper.isEmpty && outTimingForSuper.isEmpty) {
      return 'Clock In';
    } else if (inTimingForSuper.isNotEmpty && outTimingForSuper.isEmpty) {
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
              SizedBox(
                // height: 250.h,
                // width: 250.w,
                child: Lottie.asset(
                  'assets/animations/celebration.json',
                  repeat: false,
                ),
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
                     style: TextStyle(
                       fontWeight: FontWeight.bold,
                       color: Colors.teal,
                       fontSize: 18.sp,
                     ),
                   ),
                 ],
               )

            ],
          ),
        ],
      ),
    );
  }
}