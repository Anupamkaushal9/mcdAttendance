import 'dart:io';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

import 'package:mcd_attendance/Helpers/String.dart';
import 'package:mcd_attendance/Model/SupervisorEmployeeModel.dart';
import 'package:mcd_attendance/Screens/HistoryForSuperVisorScreen.dart';
import 'package:mcd_attendance/Screens/HomeScreenForSupervisor.dart';
import '../Helpers/ApiBaseHelper.dart';
import '../Model/EmployeeHistoryModel.dart';
import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class EmployeeListScreen extends StatefulWidget {
  final String comingFrom;
  const EmployeeListScreen({super.key, required this.comingFrom});

  @override
  _EmployeeListScreenState createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<SupervisorEmployeeModel> employeeList = [];
  bool isLoading = true;
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<EmpHistoryData>? empHistoryData = [];

  @override
  void initState() {
    super.initState();
    _checkInternetAndInitialize();
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

  Future<void> _checkInternetAndInitialize() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return NoInternetDialog(
            onRetry: () {
              (Platform.isAndroid)
                  ? FlutterExitApp.exitApp()
                  : FlutterExitApp.exitApp(iosForceExit: true);
            },
          );
        },
      );
      return;
    }

    await fetchEmpList();
  }

  Future<void> getEmpHistory(String empGuid) async {
    try {
      debugPrint("Fetching history for empGuid: $empGuid");

      if (!mounted) return;

      setState(() {
        isLoading = true;
      });

      await Future.delayed(const Duration(seconds: 1));

      var parameter = {
        "orgUnitGuid": "2493c2cd-5510-451d-9afe-e1a1468d0ac2",
        "month": DateTime.now().month,
        "year": DateTime.now().year,
        "empGuid": empGuid,
      };

      final getData = await apiBaseHelper.postAPICall(getEmpHistoryApi, parameter);

      String status = getData['status']?.toString() ?? 'FALSE';
      String error = getData['error']?.toString() ?? 'Unknown error';

      if (status == 'TRUE') {
        var data = getData['attendanceXML']['attendanceList'];

        if (mounted) {
          setState(() {
            empHistoryData = data
                .map<EmpHistoryData>((json) => EmpHistoryData.fromJson(json))
                .toList();
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          if(!error.contains("NO RECORD FOUND."))
          {
            _showNullValueError("getEmpHistory Api : $error $status");
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showNullValueError('getEmpHistory Api Exception: ${e.toString()}');
      }
    }
  }


  Future<void> fetchEmpList() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    var parameter = {
      "empGuid": empGuid,
      "parentPostGuid": empGuid,
    };

    try {
      var getData =
      await apiBaseHelper.postAPICall(getSupervisorEmpListApi, parameter);

      if (getData is String) {
        getData = json.decode(getData);
      }

      final String status = getData['status']?.toString() ?? 'FALSE';

      if (status == 'TRUE') {
        var employeeXML = getData['employeeXML'];
        var employeeListJson = employeeXML['employeeList'];

        if (employeeListJson is List) {
          final List<SupervisorEmployeeModel> fetchedList =
          employeeListJson.map<SupervisorEmployeeModel>((emp) {
            if (emp is Map<String, dynamic>) {
              return SupervisorEmployeeModel.fromJson(emp);
            } else {
              throw Exception('Invalid employee format');
            }
          }).toList();

          if (mounted) {
            setState(() {
              employeeList = fetchedList;
              isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              employeeList = [];
              isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            employeeList = [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          employeeList = [];
          isLoading = false;
        });
        _showNullValueError("fetchEmpList Api Exception: ${e.toString()}");
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar:  GlassAppBar(title: (widget.comingFrom =='superHistory')?'SUPERVISOR HISTORY':'SUPERVISOR ATTENDANCE', isLayoutScreen: false),
      body: isLoading
          ? Center(
        child: LottieBuilder.asset(
          'assets/animations/loading_animation.json',
          height: 50.h,
          width: 50.w,
        ),
      )
          : (employeeList.isNotEmpty)
          ? ListView.builder(
        itemCount: employeeList.length,
        itemBuilder: (context, index) {
          final user = employeeList[index];
          return GestureDetector(
            onTap: ()  {
              if (widget.comingFrom != 'superHistory') {
                 // getEmpHistory(user.empGuid ?? '').then((_) {
                 //   //if (!mounted) return; // ✅ check to avoid using disposed context
                 //
                 // });
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeSupervisorScreen(
                      bmid: user.empCode.toString(),
                      guid: user.empGuid ?? '',
                      empHistoryData: empHistoryData,
                      employeeInfoList: employeeList,
                      day: DateTime.now().day,
                    ),
                  ),
                );
              } else {
                if (!mounted) return; // ✅ check here too

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SupervisorAttendanceHistoryScreen(
                      currentMonth: DateTime.now().month.toString(),
                      currentYear: DateTime.now().year,
                      month: DateTime.now().month,
                      guid: user.empGuid ?? '',
                    ),
                  ),
                );
              }
            },
            child: Card(
              margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              elevation: 5,
              color: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.empName ?? '',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

        },
      )
          : const Center(
        child: Text('No record found'),
      ),
    );
  }
}
