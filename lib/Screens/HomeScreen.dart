import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
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
  List<EmpHistoryData>? empHistoryData = [];
  final int day;

  HomeScreen({
    super.key,
    required this.bmid,
    required this.employee,
    this.empHistoryData,
    required this.day,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final resultFormatter = DateFormat('EEEE, MMM dd');
  final timeFormatter = DateFormat('HH:mm:ss');
  String formattedTime = '';
  String _timeString = '';
  String resultDate = '';
  String clockInValue = '';
  String clockOutValue = '';
  String workingHrValue = '00:00:00';
  String dayVal = '';
  Timer? workingHoursTimer;
  Timer? realTimeTimer;
  bool isLoading = true;
  int? animatedHours;
  int? animatedMinutes;
  int? animatedSeconds;
  bool isAnimating = true;
  final Random _random = Random();
  List<int> imageBytes = [];
  File displayImage = File('');
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<OrgData> orgData = [];
  List<EmpHistoryData>? empHistoryData = [];
  bool showLoader = true;

  // Timer management variables
  bool _isDisposed = false;
  final List<Timer> _activeTimers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTimers();
    startAnimationTimer();
    print("home screen init state");
    getLastAttendance();
    getOrgList();
    final DateTime now = DateTime.now();
    formattedTime = timeFormatter.format(now);
    resultDate = resultFormatter.format(now);
    getColumnValues();
  }

  void _initializeTimers() {
    _logTimerEvent('Initializing timers');

    // Cancel existing timers if any
    workingHoursTimer?.cancel();
    realTimeTimer?.cancel();

    // Create new timers
    workingHoursTimer = _startTrackedTimer(
      const Duration(minutes: 1),
          (timer) {
        if (mounted) updateWorkingHours();
      },
    );

    if (widget.empHistoryData!.isNotEmpty &&
        widget.empHistoryData![0].outTime == null) {
      realTimeTimer = _startTrackedTimer(
        const Duration(seconds: 1),
            (timer) {
          if (mounted) updateWorkingHours();
        },
      );
    }
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

  Timer _startTrackedTimer(Duration duration, void Function(Timer) callback) {
    if (_isDisposed) {
      _logTimerEvent('Attempted to start timer after disposal');
      return Timer(Duration.zero, () {});
    }

    final timer = Timer.periodic(duration, (t) {
      if (_isDisposed) {
        t.cancel();
        return;
      }
      callback(t);
    });

    _activeTimers.add(timer);
    _logTimerEvent('Started new timer: ${duration.inSeconds}s interval');
    return timer;
  }

  void _logTimerEvent(String message) {
    final now = DateTime.now().toIso8601String();
    debugPrint('[$now] Timer Event: $message');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _logTimerEvent('App lifecycle changed to: $state');

    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - restart timers
      _logTimerEvent('App resumed - restarting timers');
      _initializeTimers();

      // Force update time displays
      final DateTime now = DateTime.now();
      if (mounted) {
        setState(() {
          _timeString = _formatDateTime(now);
          formattedTime = timeFormatter.format(now);
          resultDate = resultFormatter.format(now);
        });
      }
    } else if (state == AppLifecycleState.paused) {
      // App went to background - cancel timers to save resources
      _logTimerEvent('App paused - cancelling timers');
      workingHoursTimer?.cancel();
      realTimeTimer?.cancel();
    }
  }

  void startAnimationTimer() {
    _logTimerEvent('Starting animation timer');

    final animationTimer = _startTrackedTimer(
      const Duration(milliseconds: 250),
          (timer) {
        if (isAnimating && mounted) {
          setState(() {
            animatedHours = _random.nextInt(24);
            animatedMinutes = _random.nextInt(60);
            animatedSeconds = _random.nextInt(60);
          });
        }
      },
    );

    // Stop the animation after 2 seconds
    _startTrackedTimer(
      const Duration(seconds: 2),
          (timer) {
        if (mounted) {
          setState(() {
            isAnimating = false;
          });
          updateWorkingHours();
          timer.cancel();
          animationTimer.cancel();
        }
      },
    );
  }

  Future<void> _clearPreference() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.clear();
  }

  getLastAttendance() async {
    print('last attendance api is running');
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "empGuid": empGuid,
    };

    await apiBaseHelper.postAPICall(lastAttendanceApi, parameter).then(
          (getData) {
        String error = getData['error']?.toString() ?? '';
        String status = getData['status']?.toString() ?? '';

        if (status == 'TRUE') {
          String inTime = getData['in_time']?.toString() ?? '';
          String outTime = getData['out_time']?.toString() ?? '';

          if (mounted) {
            setState(() {
              print('In Time: $inTime');
              print('Out Time: $outTime');

              DateTime now = DateTime.now();

              if (inTime.isNotEmpty && outTime.isNotEmpty) {
                DateTime inDateTime = DateTime.parse(inTime);

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
                DateTime inDateTime = DateTime.parse(inTime);
                Duration difference = now.difference(inDateTime);

                if (difference.inHours >= 20) {
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

              showLoader = false;
            });
          }
        } else {
          if (error == 'NO RECORD FOUND.') {
            if (mounted) {
              setState(() {
                showLoader = false;
              });
              if(!isFreshUser)
                {
                  _clearPreference();
                  showDialog(
                    context: context,
                    builder: (_) => WillPopScope(
                      onWillPop: () async => false,
                      child:  SomethingWentWrongDialog(errorDetails: error,),
                    ),
                  );
                }

            }
          }

          if (error.isNotEmpty&& error != 'NO RECORD FOUND.') {
            print('Error: $error');
            _showNullValueError("getLastAttendance Api: $error $status");
          }
        }
      },
      onError: (e) {
        if (mounted) {
          _showNullValueError("getLastAttendance Api: $e");
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    print("dependency called");
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _logTimerEvent('Disposing HomeScreen - cancelling all timers');

    for (final timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();

    workingHoursTimer?.cancel();
    realTimeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void getColumnValues() async {
    await Future.delayed(const Duration(seconds: 1));
    updateWorkingHours();
  }

  void updateWorkingHours() {
    try {
      if (inTiming.isNotEmpty) {
        DateTime inTime = DateTime.parse(inTiming);
        DateFormat timeFormat = DateFormat("hh:mm a");

        if (outTiming.isNotEmpty) {
          DateTime outTime = DateTime.parse(outTiming);
          clockOutValue = timeFormat.format(outTime);

          Duration difference = outTime.difference(inTime);
          workingHrValue = _formatDuration(difference);
        } else {
          DateTime now = DateTime.now();
          Duration difference = now.difference(inTime);
          clockOutValue = '-';
          workingHrValue = _formatDuration(difference);
        }

        if (mounted) {
          setState(() {
            clockInValue = timeFormat.format(inTime);
            dayVal = DateFormat("d").format(inTime);
          });
        }
      }
    } catch (e) {
      _logTimerEvent('Error in updateWorkingHours: $e');
      if (mounted) _initializeTimers();
    }
  }

  String _formatDuration(Duration duration) {
    return "${duration.inHours.toString().padLeft(2, '0')}:"
        "${(duration.inMinutes % 60).toString().padLeft(2, '0')}:"
        "${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }


  String _formatDateTime(DateTime dateTime) {
    return DateFormat('hh:mm:ss').format(dateTime);
  }

  Future<void> getOrgList() async {
    setState(() {
      showLoader = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    var parameter = {
      "appCode": "org.dmc.smartcity",
      "loginId": userBmid,
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
            if (mounted) {
              setState(() {
                orgData = organizations.map<OrgData>((org) {
                  if (org is Map<String, dynamic>) {
                    return OrgData.fromJson(org);
                  } else {
                    throw Exception('Invalid data format in org list');
                  }
                }).toList();

                orgBasicGuid = orgData.first.orgUnitBasicGuid;
                _setOrgBasicGuidSharedPref(orgBasicGuid);
                showLoader = false;
              });
            }
          } else {
            _showNullValueError("Organization list format is invalid.");
          }
        } else {
          _showNullValueError("Organization data is missing.");
        }
      } else {
        _showNullValueError("Failed to fetch organization list: ${getData['error']+ status ?? 'Unknown error'}");
      }
    } catch (e) {
      _showNullValueError("Error occurred: ${e.toString()}");
    }
  }


  Future<void> _setOrgBasicGuidSharedPref(String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('orgUnitBasicGuid', value!);

    if (mounted) {
      setState(() {
        orgUnitBasicGuid = prefs.getString('orgUnitBasicGuid')!;
      });
    }
    print('orgUnitBasicGuid = $orgUnitBasicGuid');
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    Future.delayed(const Duration(seconds: 1), () async {
      if (mounted) {
        setState(() {
          showLoader = false;
        });
      }
    });

    return (showLoader)
        ? Center(
      child: LottieBuilder.asset(
        'assets/animations/loading_animation.json',
        height: 50.h,
        width: 50.w,
      ),
    )
        : Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: (!isLoading)?true:false,
      body: ListView(
        padding: const EdgeInsets.all(5),
        children: <Widget>[
          SizedBox(
            height: height / 7,
            child: Column(
              children: [
                SizedBox(
                  height: 20.h,
                ),
                Center(
                  child: inTiming == "empty"
                      ? Text(
                    "00:00:00",
                    style: TextStyle(
                      fontSize: 50.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  )
                      : Text(
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
          SizedBox(
            child: Center(
              child: Text(
                resultDate,
                style: TextStyle(
                  fontSize: 25.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          SizedBox(height: 30.h),
          SizedBox(
            height: height / 6.5,
            child: Row(
              children: [
                Expanded(
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          'assets/images/clock-rotate-left-icon.svg',
                          height: 30.h,
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          inTiming.isNotEmpty ? clockInValue : '-',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 25.0.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Center(child: Text('In Time'))
                      ],
                    )),
                Expanded(
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          'assets/images/clock-rotate-right-icon.svg',
                          height: 30.h,
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          outTiming.isNotEmpty ? clockOutValue : '-',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 25.0.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Center(child: Text('Out Time'))
                      ],
                    )),
              ],
            ),
          ),
          (outTiming.isEmpty)
              ? SizedBox(height: height / 20)
              : const SizedBox(height: 0),
          (outTiming.isEmpty)
              ? SizedBox(
            height: height / 4,
            child: GestureDetector(
              onTap: () {
                if (mounted) {
                  setState(() {
                    checkForMockLocation(context);
                    getOrgList();
                  });
                }
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => InAttendanceScreen(
                          empHistoryData: widget.empHistoryData,
                          employee: widget.employee,
                        ))).then((value) {
                  debugPrint(value);
                });
              },
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      height: 220.h,
                      width: 220.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                        inTiming.isEmpty && outTiming.isEmpty
                            ? const LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            Colors.greenAccent,
                            Colors.lightGreen,
                          ],
                        )
                            : inTiming.isNotEmpty &&
                            outTiming.isEmpty
                            ? const LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            Colors.redAccent,
                            Color(0xFFFFCDD2),
                          ],
                        )
                            : const LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            Colors.grey,
                            Colors.grey,
                          ],
                        ),
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
                          LottieBuilder.asset(
                            height: 160.h,
                            width: 160.w,
                            'assets/animations/hand_click_animation.json',
                          ),
                          inTiming.isEmpty && outTiming.isEmpty
                              ? Text(textScaleFactor: (width>500)?0.8:1,
                            'Clock In',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: (height < 600)
                                  ? 20.0.sp
                                  : 25.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                              : inTiming.isNotEmpty &&
                              outTiming.isEmpty
                              ? Text(textScaleFactor: (width>500)?0.8:1,
                            'Clock Out',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: (height < 600)
                                  ? 20.0.sp
                                  : 25.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                              : const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
              : Center(
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
          ),
        ],
      ),
    );
  }
}