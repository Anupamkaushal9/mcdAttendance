import 'dart:convert';
import 'dart:io';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Screens/EmployeeListScreen.dart';
import 'package:mcd_attendance/Screens/HomeScreen.dart';
import 'package:mcd_attendance/Screens/HomeScreenForSupervisor.dart';
import 'package:mcd_attendance/Screens/LayoutScreen.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../Helpers/ApiBaseHelper.dart';
import '../../Helpers/NotificationService.dart';
import '../../Helpers/String.dart';
import '../../Model/EmployeeHistoryModel.dart';
import '../LoginScreen.dart';
import '../UserSearchScreen.dart';

Future<void> _clearPreference() async {
  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.clear();
}

class DeviceRegisterDialog extends StatelessWidget {
  const DeviceRegisterDialog({super.key});

  @override
  Widget build(BuildContext context) {
    print("=====dialog======");
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Success Icon
          LottieBuilder.asset(
            'assets/animations/deviceError.json', // Provide the correct asset path
            height: 200.h,
            width: 200.w,
            repeat: false,
          ),
           SizedBox(height: 16.h),
           Text(
            "DEVICE NOT REGISTERED.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
           SizedBox(height: 10.h),
           Text(
            "Please register the device first! ",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.black87,
            ),
          ),
           SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff111184),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const UserSearchScreen()),
                  (Route<dynamic> route) => false,
                );
                // Navigator.pop(context);
              },
              child:  Text(
                "Register",
                style: TextStyle(fontSize: 16.sp, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceAlreadyRegisteredDialog extends StatelessWidget {
  const DeviceAlreadyRegisteredDialog({super.key});

  @override
  Widget build(BuildContext context) {
    print("=====Device Already Registered Dialog======");
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Error Icon (You can use any animation or replace it with a static icon)
          LottieBuilder.asset(
            'assets/animations/alert.json', // Provide the correct asset path for the error animation
            repeat: false,
          ),
           SizedBox(height: 5.h),
           Text(
            "OTHER DEVICE ALREADY REGISTERED TO THIS USER!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
           SizedBox(height: 10.h),
           Text(
            "Please de-register first from old device!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.black87,
            ),
          ),
           SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff111184),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                (Platform.isAndroid)?FlutterExitApp.exitApp():FlutterExitApp.exitApp(iosForceExit: true);
              },
              child:  Text(
                "Okay",
                style: TextStyle(fontSize: 16.sp, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceAlreadyAssignedDialog extends StatelessWidget {
  final String text;
  const DeviceAlreadyAssignedDialog({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    print("=====Device Already Assigned Dialog======");
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Error Icon (You can use any animation or replace it with a static icon)
          LottieBuilder.asset(
            'assets/animations/alert.json', // Provide the correct asset path for the error animation
            repeat: false,
          ),
           SizedBox(height: 5.h),
          Text(
            text,
            textAlign: TextAlign.center,
            style:  TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
           SizedBox(height: 10.h),
           Text(
            "",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.black87,
            ),
          ),
           SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff111184),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                (Platform.isAndroid)?FlutterExitApp.exitApp():FlutterExitApp.exitApp(iosForceExit: true);
              },
              child:  Text(
                "Okay",
                style: TextStyle(fontSize: 16.sp, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SuccessDialog extends StatefulWidget {
  final String? messageApi;
  const SuccessDialog({super.key, this.messageApi});

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog> {
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<EmpHistoryData>? empHistoryData = [];
  bool isLoading = false;

  getLastAttendance() async {
    print("History is running");
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "empGuid": empGuid,
    };
    await apiBaseHelper.postAPICall(lastAttendanceApi, parameter).then(
      (getData) {
        String error = getData['error']?.toString() ??
            ''; // Handle case where error key might be missing
        String status = getData['status']?.toString() ?? '';

        if (status == 'TRUE') {
          String inTime = getData['in_time']?.toString() ?? '';
          String outTime = getData['out_time']?.toString() ?? '';

          setState(() {
            print('In Time: $inTime');
            print('Out Time: $outTime');

            isLoading = false;
          });
        } else {
          // Handle NO RECORD FOUND or other error cases
          setState(() {
            isLoading = false;
          });
          if (error.isNotEmpty) {
            // Show an appropriate message, maybe using a SnackBar or alert
            print('Error: $error');
          }
        }
      },
      onError: (e) {
        SnackBar(content: Text(e.toString())); // Show the error message
      },
    );
  }

  getEmpHistory() async {
    print("History is running");
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "orgUnitGuid": "2493c2cd-5510-451d-9afe-e1a1468d0ac2",
      "month": DateTime.now().month,
      "year": DateTime.now().year,
      "empGuid": empGuid
    };
    await apiBaseHelper.postAPICall(getEmpHistoryApi, parameter).then(
        (getData) {
      String error = getData['error'].toString();
      String? msg = getData['status'].toString();
      if (msg == 'TRUE') {
        var data = getData['attendanceXML']['attendanceList'];
        setState(() {
          // empHistoryData = [EmpHistoryData.fromJson(data)];
          empHistoryData = data
              .map<EmpHistoryData>((json) => EmpHistoryData.fromJson(json))
              .toList();
          print(' = $empHistoryData');
          isLoading = true;
        });
      } else {
        isLoading = true;
      }
    }, onError: (e) {
      SnackBar(content: Text(e.toString()!));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Success Icon
          LottieBuilder.asset(
            'assets/animations/success_animation.json', // Provide the correct asset path
            width: 100.w,
            height: 100.h,
            repeat: false,
          ),
           SizedBox(height: 16.h),
           Text(
            "Attendance Marked Successfully",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
           SizedBox(height: 10.h),
           Text(
            "Face recognized successfully. You may proceed.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.black87,
            ),
          ),
           SizedBox(height: 10.h),
          Text(
            widget.messageApi??'',
            textAlign: TextAlign.center,
            style:  TextStyle(
              fontSize: 16.sp,
              color: Colors.blueAccent,
            ),
          ),
           SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                getLastAttendance().then((getData) {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => LayoutScreen(
                              bmid: userBmid,
                              empData: empTempData,
                            )),
                    (Route<dynamic> route) => false,
                  );
                });
              },
              child: (isLoading)
                  ?  Center(
                      child: SizedBox(
                        height: 20.h,
                        width: 20.w,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                    )
                  :  Text(
                      "Okay",
                      style: TextStyle(fontSize: 16.sp,color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class SuccessDialogForSuper extends StatefulWidget {
  final String? messageApi;
  final String? guid;
  const SuccessDialogForSuper({super.key, this.messageApi,this.guid});

  @override
  State<SuccessDialogForSuper> createState() => _SuccessDialogForSuperState();
}

class _SuccessDialogForSuperState extends State<SuccessDialogForSuper> {
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<EmpHistoryData>? empHistoryData = [];
  bool isLoading = false;

  getLastAttendance() async {
    print("History is running");
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "empGuid": widget.guid,
    };
    await apiBaseHelper.postAPICall(lastAttendanceApi, parameter).then(
          (getData) {
        String error = getData['error']?.toString() ??
            ''; // Handle case where error key might be missing
        String status = getData['status']?.toString() ?? '';

        if (status == 'TRUE') {
          String inTime = getData['in_time']?.toString() ?? '';
          String outTime = getData['out_time']?.toString() ?? '';

          setState(() {
            print('In Time: $inTime');
            print('Out Time: $outTime');

            isLoading = false;
          });
        } else {
          // Handle NO RECORD FOUND or other error cases
          setState(() {
            isLoading = false;
          });
          if (error.isNotEmpty) {
            // Show an appropriate message, maybe using a SnackBar or alert
            print('Error: $error');
          }
        }
      },
      onError: (e) {
        SnackBar(content: Text(e.toString())); // Show the error message
      },
    );
  }

  getEmpHistory() async {
    print("History is running");
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "orgUnitGuid": "2493c2cd-5510-451d-9afe-e1a1468d0ac2",
      "month": DateTime.now().month,
      "year": DateTime.now().year,
      "empGuid": widget.guid
    };
    await apiBaseHelper.postAPICall(getEmpHistoryApi, parameter).then(
            (getData) {
          String error = getData['error'].toString();
          String? msg = getData['status'].toString();
          if (msg == 'TRUE') {
            var data = getData['attendanceXML']['attendanceList'];
            setState(() {
              // empHistoryData = [EmpHistoryData.fromJson(data)];
              empHistoryData = data
                  .map<EmpHistoryData>((json) => EmpHistoryData.fromJson(json))
                  .toList();
              print(' = $empHistoryData');
              isLoading = true;
            });
          } else {
            isLoading = true;
          }
        }, onError: (e) {
      SnackBar(content: Text(e.toString()!));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Success Icon
          LottieBuilder.asset(
            'assets/animations/success_animation.json', // Provide the correct asset path
            width: 100.w,
            height: 100.h,
            repeat: false,
          ),
           SizedBox(height: 16.h),
           Text(
            "Attendance Marked Successfully",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
           SizedBox(height: 10.h),
          Text(
            "Face recognized successfully. You may proceed.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.black87,
            ),
          ),
           SizedBox(height: 10.h),
          Text(
            widget.messageApi??'',
            textAlign: TextAlign.center,
            style:  TextStyle(
              fontSize: 16.sp,
              color: Colors.blueAccent,
            ),
          ),
           SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                getEmpHistory().then((getData) {
                  getLastAttendance();
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const EmployeeListScreen(comingFrom: 'superHome',)),
                        (route) => route.isFirst, // Remove all previous routes
                  );
                });
              },
              child: (isLoading)
                  ?  Center(
                child: SizedBox(
                  height: 20.h,
                  width: 20.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              )
                  :  Text(
                "Okay",
                style: TextStyle(fontSize: 16.sp,color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SuccessDialogNormal extends StatefulWidget {
  final String? messageApi;
  const SuccessDialogNormal({super.key, this.messageApi});

  @override
  State<SuccessDialogNormal> createState() => _SuccessDialogNormalState();
}

class _SuccessDialogNormalState extends State<SuccessDialogNormal> {
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<EmpHistoryData>? empHistoryData = [];
  bool isLoading = false;


  getLastAttendance() async {
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "empGuid": empGuid,
    };
    await apiBaseHelper.postAPICall(lastAttendanceApi, parameter).then(
          (getData) {
        String error = getData['error']?.toString() ??
            ''; // Handle case where error key might be missing
        String status = getData['status']?.toString() ?? '';

        if (status == 'TRUE') {
          String inTime = getData['in_time']?.toString() ?? '';
          String outTime = getData['out_time']?.toString() ?? '';

          setState(() {
            print('In Time: $inTime');
            print('Out Time: $outTime');

            isLoading = false;
          });
        } else {
          // Handle NO RECORD FOUND or other error cases
          setState(() {
            isLoading = false;
          });
          if (error.isNotEmpty) {
            // Show an appropriate message, maybe using a SnackBar or alert
            print('Error: $error');
          }
        }
      },
      onError: (e) {
        SnackBar(content: Text(e.toString())); // Show the error message
      },
    );
  }

  getEmpHistory() async {
    print("History is running");
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "orgUnitGuid": "2493c2cd-5510-451d-9afe-e1a1468d0ac2",
      "month": DateTime.now().month,
      "year": DateTime.now().year,
      "empGuid": empGuid
    };
    await apiBaseHelper.postAPICall(getEmpHistoryApi, parameter).then(
            (getData) {
          String error = getData['error'].toString();
          String? msg = getData['status'].toString();
          if (msg == 'TRUE') {
            var data = getData['attendanceXML']['attendanceList'];
            setState(() {
              // empHistoryData = [EmpHistoryData.fromJson(data)];
              empHistoryData = data
                  .map<EmpHistoryData>((json) => EmpHistoryData.fromJson(json))
                  .toList();
              print(' = $empHistoryData');
              isLoading = true;
            });
          } else {
            isLoading = true;
          }
        }, onError: (e) {
      SnackBar(content: Text(e.toString()!));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Success Icon
          LottieBuilder.asset(
            'assets/animations/success_animation.json', // Provide the correct asset path
            width: 100.w,
            height: 100.h,
            repeat: false,
          ),
           SizedBox(height: 16.h),
           Text(
            "Attendance Marked Successfully",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
           SizedBox(height: 10.h),
           Text(
            "Attendance Done. You may proceed.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.black87,
            ),
          ),
           SizedBox(height: 10.h),
           Text(
            widget.messageApi??'',
            textAlign: TextAlign.center,
            style:  TextStyle(
              fontSize: 16.sp,
              color: Colors.blueAccent,
            ),
          ),
           SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                getEmpHistory().then((getData) {
                  getLastAttendance();
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => LayoutScreen(
                          bmid: userBmid,
                          empData: empTempData,
                        )),
                        (Route<dynamic> route) => false,
                  );
                });
              },
              child: (isLoading)
                  ?  Center(
                child: SizedBox(
                  height: 20.h,
                  width: 20.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              )
                  :  Text(
                "Okay",
                style: TextStyle(fontSize: 16.sp,color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SuccessDialogNormalForSupervisor extends StatefulWidget {
  final String? messageApi;
  final String guid;
  const SuccessDialogNormalForSupervisor({super.key, this.messageApi, required this.guid,});

  @override
  State<SuccessDialogNormalForSupervisor> createState() => _SuccessDialogNormalForSupervisorState();
}

class _SuccessDialogNormalForSupervisorState extends State<SuccessDialogNormalForSupervisor> {
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<EmpHistoryData>? empHistoryData = [];
  bool isLoading = false;


  getLastAttendance() async {
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "empGuid": widget.guid,
    };
    await apiBaseHelper.postAPICall(lastAttendanceApi, parameter).then(
          (getData) {
        String error = getData['error']?.toString() ??
            ''; // Handle case where error key might be missing
        String status = getData['status']?.toString() ?? '';

        if (status == 'TRUE') {
          String inTime = getData['in_time']?.toString() ?? '';
          String outTime = getData['out_time']?.toString() ?? '';

          setState(() {
            print('In Time: $inTime');
            print('Out Time: $outTime');

            isLoading = false;
          });
        } else {
          // Handle NO RECORD FOUND or other error cases
          setState(() {
            isLoading = false;
          });
          if (error.isNotEmpty) {
            // Show an appropriate message, maybe using a SnackBar or alert
            print('Error: $error');
          }
        }
      },
      onError: (e) {
        SnackBar(content: Text(e.toString())); // Show the error message
      },
    );
  }

  getEmpHistory() async {
    print("History is running");
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "orgUnitGuid": "2493c2cd-5510-451d-9afe-e1a1468d0ac2",
      "month": DateTime.now().month,
      "year": DateTime.now().year,
      "empGuid": widget.guid
    };
    await apiBaseHelper.postAPICall(getEmpHistoryApi, parameter).then(
            (getData) {
          String error = getData['error'].toString();
          String? msg = getData['status'].toString();
          if (msg == 'TRUE') {
            var data = getData['attendanceXML']['attendanceList'];
            setState(() {
              // empHistoryData = [EmpHistoryData.fromJson(data)];
              empHistoryData = data
                  .map<EmpHistoryData>((json) => EmpHistoryData.fromJson(json))
                  .toList();
              print(' = $empHistoryData');
              isLoading = true;
            });
          } else {
            isLoading = true;
          }
        }, onError: (e) {
      SnackBar(content: Text(e.toString()!));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Success Icon
          LottieBuilder.asset(
            'assets/animations/success_animation.json', // Provide the correct asset path
            width: 100.w,
            height: 100.h,
            repeat: false,
          ),
           SizedBox(height: 16.h),
           Text(
            "Attendance Marked Successfully",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
           SizedBox(height: 10.h),
           Text(
            "Attendance Done. You may proceed.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.black87,
            ),
          ),
           SizedBox(height: 10.h),
          Text(
            widget.messageApi??'',
            textAlign: TextAlign.center,
            style:  TextStyle(
              fontSize: 16.sp,
              color: Colors.blueAccent,
            ),
          ),
           SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                getEmpHistory().then((getData) {
                  getLastAttendance();
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const EmployeeListScreen(comingFrom: 'superHome',)),
                        (route) => route.isFirst, // Remove all previous routes
                  );
                });
              },
              child: (isLoading)
                  ?  Center(
                child: SizedBox(
                  height: 20.h,
                  width: 20.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              )
                  :  Text(
                "Okay",
                style: TextStyle(fontSize: 16.sp,color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FailureDialog extends StatelessWidget {
  final VoidCallback onTryAgain;
  final String? comingFrom;
  const FailureDialog({Key? key, required this.onTryAgain,this.comingFrom}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Lottie Asset for Failure
          LottieBuilder.asset(
            'assets/animations/fail_animation.json', // Provide the correct asset path
            width: 100.w,
            height: 100.h,
            repeat: false,
          ),
           SizedBox(height: 16.h),
           Text(
            "Attendance Failed",
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
           SizedBox(height: 10.h),
           Text(
            "Face not recognized. Please try again or cancel to exit.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.black87,
            ),
          ),
           SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close the dialog
                    onTryAgain(); // Call onTryAgain callback
                  },
                  child:  Text(
                    "Try Again",
                    style: TextStyle(fontSize: 16.sp, color: Colors.white),
                  ),
                ),
              ),
               SizedBox(
                width: 15.w,
              ),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    (comingFrom=='inAttendance')?Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LayoutScreen(
                            bmid: userBmid,
                            empData: empTempData,
                          )),
                          (Route<dynamic> route) => false,
                    ):Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const EmployeeListScreen(comingFrom: 'superHome',)),
                          (route) => route.isFirst, // Remove all previous routes
                    );
                  },
                  child:  Text(
                    "Cancel",
                    style: TextStyle(fontSize: 16.sp,color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FailureDialogNormal extends StatelessWidget {
  final VoidCallback onTryAgain;
  final VoidCallback onCancel;
  final String? messageApi;
  final String? comingFrom ;
  const FailureDialogNormal({Key? key, required this.onTryAgain, this.messageApi, required this.onCancel,this.comingFrom}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Lottie Asset for Failure
          LottieBuilder.asset(
            'assets/animations/fail_animation.json', // Provide the correct asset path
            width: 100.w,
            height: 100.h,
            repeat: false,
          ),
           SizedBox(height: 16.h),
           Text(
            "Attendance Failed",
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
           SizedBox(height: 10.h),
           Text(
           messageApi??'',
            textAlign: TextAlign.center,
            style:  TextStyle(
              fontSize: 16.sp,
              color: Colors.blueAccent,
            ),
          ),
          Visibility(visible: messageApi!='',
              child:  SizedBox(height: 10.h)),
           Text(
            "Please try again!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.black87,
            ),
          ),
           SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    (comingFrom=='inAttendance')?Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LayoutScreen(
                            bmid: userBmid,
                            empData: empTempData,
                          )),
                          (Route<dynamic> route) => false,
                    ):Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const EmployeeListScreen(comingFrom: 'superHome',)),
                          (route) => route.isFirst, // Remove all previous routes
                    );
                    onCancel();
                  },
                  child:  Text(
                    "Okay",
                    style: TextStyle(fontSize: 16.sp,color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LogoutConfirmationDialog extends StatelessWidget {
  const LogoutConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Optionally, add an icon or animation for a logout confirmation
          LottieBuilder.asset(
            'assets/animations/logout_confirmation.json', // Provide the correct asset path
            height: 150.h,
            width: 150.w,
            repeat: false,
          ),
           SizedBox(height: 5.h),
           Text(
            "Are you sure you want to logout?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
           SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Cancel Button
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close the dialog
                  },
                  child:  Text(
                    "Cancel",
                    style: TextStyle(fontSize: 16.sp, color: Colors.white),
                  ),
                ),
              ),
               SizedBox(
                width: 10.w,
              ),
              // Yes Button
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    // Add your logout logic here
                    _clearPreference();
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen(
                                  isLoggingOut: true,
                                )));
                  },
                  child:  Text(
                    "Yes",
                    style: TextStyle(fontSize: 16.sp, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



class LoadingDialog extends StatelessWidget {
  const LoadingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        contentPadding: const EdgeInsets.all(20),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LottieBuilder.asset(
              'assets/animations/loading_animation.json', // Provide the correct asset path
              width: 50.w,
              height: 50.h,
              repeat: false,
            ),
             SizedBox(height: 16.h),
             Text(
              'Please wait...while de-registering',
              style: TextStyle(fontSize: 16.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class DeRegisterConfirmationDialog extends StatelessWidget {
  const DeRegisterConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Optionally, add an icon or animation for a logout confirmation
          LottieBuilder.asset(
            'assets/animations/device_confirmation.json', // Provide the correct asset path
            width: 150.w,
            height: 150.h,
            repeat: false,
          ),
           SizedBox(height: 16.h),
           Text(
            "Are you sure you want to de-register?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
           SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancel Button
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close the dialog
                  },
                  child:  Text(
                    "Cancel",
                    style: TextStyle(fontSize: 16.sp, color: Colors.white),
                  ),
                ),
              ),
              // Yes Button
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    // Add your logout logic here
                    _clearPreference();
                    Future.delayed(const Duration(seconds: 1), () {
                      Navigator.pop(context); // Close the current screen
                      (Platform.isAndroid)?FlutterExitApp.exitApp():FlutterExitApp.exitApp(iosForceExit: true); // Close the entire app
                    });
                  },
                  child:  Text(
                    "Yes",
                    style: TextStyle(fontSize: 16.sp, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NoInternetDialog extends StatelessWidget {
  final VoidCallback onRetry;

  const NoInternetDialog({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // You can use a Lottie animation for no internet or any static icon
            LottieBuilder.asset(
              'assets/animations/no_internet.json', // Put the correct asset path for no internet animation
              repeat: false,
            ),
             SizedBox(height: 5.h),
             Text(
              "No Internet Connection!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
             SizedBox(height: 10.h),
             Text(
              "Please check your internet connection and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.black87,
              ),
            ),
             SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel Button
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff111184),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close the dialog
                      (Platform.isAndroid)?FlutterExitApp.exitApp():FlutterExitApp.exitApp(iosForceExit: true);
                    },
                    child:  Text(
                      "Okay",
                      style: TextStyle(fontSize: 16.sp, color: Colors.white),
                    ),
                  ),
                ),
                // Try Again Button
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OutOfOfficeDialog extends StatelessWidget {
  const OutOfOfficeDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // You can use a Lottie animation for no internet or any static icon
          LottieBuilder.asset(
            'assets/animations/alert.json', // Put the correct asset path for no internet animation
            width: 100.w,
            height: 100.h,
            repeat: false,
          ),
           SizedBox(height: 5.h),
           Text(
            "You are out of office!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
           SizedBox(height: 10.h),
           Text(
            "Please write the reason then proceed!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.black87,
            ),
          ),
           SizedBox(height: 20.h),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff111184),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                // Navigator.popUntil(context, (route) => route.isFirst);
              },
              child:  Text(
                "Okay",
                style: TextStyle(fontSize: 16.sp, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TimeOutDialog extends StatelessWidget {
  const TimeOutDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // You can use a Lottie animation for no internet or any static icon
          LottieBuilder.asset(
            'assets/animations/timeout.json', // Put the correct asset path for no internet animation
            width: 200.w,
            height: 200.h,
            repeat: false,
          ),
           SizedBox(height: 5.h),
           Text(
            "Attendance time is over!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
           SizedBox(height: 10.h),
           Text(
            "Please try to mark the attendance again",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.black87,
            ),
          ),
           SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff111184),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child:  Text(
                "Okay",
                style: TextStyle(fontSize: 16.sp, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SomethingWentWrongDialog extends StatelessWidget {
  final String errorDetails;
  const SomethingWentWrongDialog({
    super.key, required this.errorDetails,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // You can use a Lottie animation for no internet or any static icon
            LottieBuilder.asset(
              'assets/animations/something_went_wrong.json', // Put the correct asset path for no internet animation
              repeat: true,
              height: 200.h,
              width: 200.w,
              fit :BoxFit.fitWidth
            ),
             SizedBox(height: 5.h),
             Text(
              "Something went wrong!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
             SizedBox(height: 10.h),
            const Text('Please contact IT support with the following details:',textAlign: TextAlign.center,),
             SizedBox(height: 10.h),
            Text(
              errorDetails,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
             SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff111184),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  (Platform.isAndroid)?FlutterExitApp.exitApp():FlutterExitApp.exitApp(iosForceExit: true);// Close the dialog
                  Navigator.pop(context);
                },
                child:  Text(
                  "Okay",
                  style: TextStyle(fontSize: 16.sp, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationExceptionDialog extends StatelessWidget {
  final String errorDetails;
  const LocationExceptionDialog({
    super.key, required this.errorDetails,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // You can use a Lottie animation for no internet or any static icon
            LottieBuilder.asset(
                'assets/animations/something_went_wrong.json', // Put the correct asset path for no internet animation
                repeat: true,
                height: 200.h,
                width: 200.w,
                fit :BoxFit.fitWidth
            ),
            SizedBox(height: 5.h),
            Text(
              "Location Exception Error!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 10.h),
            const Text('Please restart your device then try again',textAlign: TextAlign.center,),
            SizedBox(height: 10.h),
            Text(
              errorDetails,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff111184),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  (Platform.isAndroid)?FlutterExitApp.exitApp():FlutterExitApp.exitApp(iosForceExit: true);// Close the dialog
                  Navigator.pop(context);
                },
                child:  Text(
                  "Okay",
                  style: TextStyle(fontSize: 16.sp, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeRegisterSuccessDialog extends StatelessWidget {
  const DeRegisterSuccessDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // You can use a static icon or Lottie animation here if you want
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 100.sp,
            ),
            SizedBox(height: 10.h),
            Text(
              "De_Registration Done!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff111184),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  (Platform.isAndroid)
                      ? FlutterExitApp.exitApp()
                      : FlutterExitApp.exitApp(iosForceExit: true);
                },
                child: Text(
                  "Okay",
                  style: TextStyle(fontSize: 16.sp, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      )

    );
  }
}

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Icon(Icons.warning, color: Colors.orangeAccent, size: 70),
             SizedBox(height: 5.h),
             Text(
              "Updates are available",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
             SizedBox(height: 10.h),
             Text(
              "Update the app",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.black87,
              ),
            ),
             SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:  const Color(0xff111184),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  (Platform.isAndroid)
                      ? FlutterExitApp.exitApp()
                      : FlutterExitApp.exitApp(iosForceExit: true);
                },
                child: const Text(
                  "Okay",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


