import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/AppBtn.dart';
import '../Helpers/Session.dart';
import '../Helpers/String.dart';
import '../Model/EmployeeHistoryModel.dart';
import 'Widgets/DialogBox.dart';
import 'Widgets/EmpHistoryWidget.dart';
import 'Widgets/GlassAppbar.dart';

class SupervisorAttendanceHistoryScreen extends StatefulWidget {
  final List<EmpHistoryData>? empHistoryData;
  final String guid;
  final String currentMonth;
  final int currentYear;
  final int month;
  const SupervisorAttendanceHistoryScreen(
      {super.key,
        this.empHistoryData,
        required this.currentMonth,
        required this.currentYear,
        required this.month, required this.guid});

  @override
  State<SupervisorAttendanceHistoryScreen> createState() =>
      _SupervisorAttendanceHistoryScreenState();
}

class _SupervisorAttendanceHistoryScreenState extends State<SupervisorAttendanceHistoryScreen>
    with TickerProviderStateMixin {
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  bool _isNetworkAvail = true;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  late Animation<double> _animation;
  late AnimationController _anController;
  Animation? buttonSqueezeanimation;
  AnimationController? buttonController;
  double deviceWidth =
      WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width;

  int month = 0;
  int checkMonth = 0;
  int year = 0;
  List<EmpHistoryData>? empHistoryData = [];
  String currMonth = '';

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

    checkNetwork();
    setState(() {
      month = widget.month;
      checkMonth = widget.month;
      year = widget.currentYear;
      empHistoryData = widget.empHistoryData ?? [];
      currMonth = DateFormat('MMM').format(DateTime(year, month));
    });
    _anController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation =
        CurvedAnimation(parent: _anController, curve: Curves.easeInOut);
    // Initialize button controller animation
    buttonController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);
    buttonSqueezeanimation =
        Tween(begin: deviceWidth * 0.7, end: 50.0).animate(CurvedAnimation(
          parent: buttonController!,
          curve: const Interval(0.0, 0.150),
        ));
    getEmpHistory();
  }

  Future<void> checkNetwork() async {
    _isNetworkAvail = await isNetworkAvailable();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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

  Future<void> getEmpHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    var parameter = {
      "orgUnitGuid": "2493c2cd-5510-451d-9afe-e1a1468d0ac2",
      "month": "$month",
      "year": "$year",
      "empGuid": widget.guid,
    };

    try {
      var getData = await apiBaseHelper.postAPICall(getEmpHistoryApi, parameter);

      String status = getData['status'].toString();

      if (status == 'TRUE') {
        var data = getData['attendanceXML']['attendanceList'] ?? [];

        if (data is List) {
          if (mounted) {
            setState(() {
              empHistoryData = data
                  .map<EmpHistoryData>((json) => EmpHistoryData.fromJson(json))
                  .toList();
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              empHistoryData = [];
              _isLoading = false;
            });
          }
        }
      } else {
        if(getData['error']!='NO RECORD FOUND.')
          {
            _showNullValueError("getEmpHistory Api: ${getData['error'] ?? 'Unknown error'}");
          }

        if (mounted) {
          setState(() {
            empHistoryData = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      _showNullValueError("getEmpHistory Api Exception: ${e.toString()}");
      if (mounted) {
        setState(() {
          empHistoryData = [];
          _isLoading = false;
        });
      }
    }
  }



  @override
  void dispose() {
    _anController.dispose();
    buttonController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: 'HISTORY', isLayoutScreen: false),
        body: (!_isLoading)?Padding(
          padding:  EdgeInsets.only(left: 8.0,right: 8.0,bottom: 8.0,top: kToolbarHeight+ MediaQuery.of(context).padding.top),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Divider(height: 1),
              Row(
                children: [
                  // Previous Month Button
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: () {
                          empHistoryData?.clear();
                          setState(() {
                            if (month == 1) {
                              month = 12;
                              year = (year - 1);
                            } else {
                              month = (month - 1);
                            }
                            currMonth =
                                DateFormat('MMMM').format(DateTime(year, month));
                            _isLoading = true;
                          });
                          getEmpHistory();
                        },
                      ),
                    ),
                  ),
                  // Month & Year Display
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$currMonth ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 18.sp,
                          ),
                        ),
                        TextSpan(
                          text: '$year',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 18.sp,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center, // Optional: center or left align
                  ),
                  // Next Month Button
                  Expanded(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded),
                        onPressed: () {
                          // Only allow the month to change if it's not the current month
                          if (month == DateTime.now().month &&
                              year == DateTime.now().year) {
                            // You can optionally show a notification or return early
                            return;
                          }

                          // Clear the previous employee history data
                          empHistoryData?.clear();

                          // Update the month and year
                          setState(() {
                            if (month == 12) {
                              month = 1;
                              year = year + 1;
                            } else {
                              month = month + 1;
                            }
                            currMonth =
                                DateFormat('MMMM').format(DateTime(year, month));
                            _isLoading = true; // Ensure loading state is set
                          });

                          // Fetch the new employee history data after the month change
                          getEmpHistory();
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              // Container(
              //   padding: const EdgeInsets.only(top: 12, bottom: 12),
              //   color: Colors.grey[200],
              //   child: const Row(
              //     mainAxisAlignment: MainAxisAlignment.center,
              //     crossAxisAlignment: CrossAxisAlignment.center,
              //     children: [
              //       Expanded(
              //         child: Center(
              //           child: Text(
              //             'Date',
              //             style: TextStyle(fontWeight: FontWeight.bold),
              //           ),
              //         ),
              //       ),
              //       Expanded(
              //         child: Center(
              //           child: FittedBox(
              //             fit: BoxFit.scaleDown,
              //             child: Text(
              //               'Clock In',
              //               style: TextStyle(fontWeight: FontWeight.bold),
              //             ),
              //           ),
              //         ),
              //       ),
              //       Expanded(
              //         child: Center(
              //           child: FittedBox(
              //             fit: BoxFit.scaleDown,
              //             child: Text(
              //               'Clock Out',
              //               style: TextStyle(fontWeight: FontWeight.bold),
              //             ),
              //           ),
              //         ),
              //       ),
              //       Expanded(
              //         child: Center(
              //           child: FittedBox(
              //             fit: BoxFit.scaleDown,
              //             child: Text(
              //               "Working Hrs",
              //               style: TextStyle(fontWeight: FontWeight.bold),
              //             ),
              //           ),
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              Expanded(
                child: _isLoading
                    ? Center(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height / 2,
                    child: Center(
                      child: LottieBuilder.asset(
                        'assets/animations/loading_animation.json',
                        height: 50.h,
                        width: 50.w,
                      ),
                    ),
                  ),
                )
                    : _isNetworkAvail
                    ? (empHistoryData!.isNotEmpty
                    ? ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.vertical,
                  padding: EdgeInsets.zero,
                  itemCount: empHistoryData!.length,
                  itemBuilder: (BuildContext context, int index) {
                    return EmpHistoryWidget(
                      empHistoryData: empHistoryData![index],
                      index: index,
                    );
                  },
                )
                    : const Center(child: Text("No data found")))
                    : noInternet(context),
              ),
            ],
          ),
        ):Center(
          child: LottieBuilder.asset(
            'assets/animations/loading_animation.json',
            height: 50.h,
            width: 50.w,
          ),
        ),);
  }

  Future<void> _playAnimation() async {
    try {
      await buttonController!.forward();
    } on TickerCanceled {}
  }

  Widget noInternet(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.only(top: kToolbarHeight),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          noIntImage(),
          noIntText(context),
          noIntDec(context),
          AppBtn(
            title: getTranslated(context, 'TRY_AGAIN_INT_LBL'),
            btnAnim: buttonSqueezeanimation,
            btnCntrl: buttonController,
            onBtnSelected: () async {
              _playAnimation();
              Future.delayed(const Duration(seconds: 2)).then((_) async {
                _isNetworkAvail = await isNetworkAvailable();
                if (_isNetworkAvail) {
                  Navigator.pushReplacement(
                      context,
                      CupertinoPageRoute(
                          builder: (BuildContext context) => super.widget));
                } else {
                  await buttonController!.reverse();
                  if (mounted) setState(() {});
                }
              });
            },
          )
        ]),
      ),
    );
  }
}
