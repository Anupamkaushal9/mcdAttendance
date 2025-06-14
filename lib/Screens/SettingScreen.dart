import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mcd_attendance/Helpers/String.dart';
import 'package:mcd_attendance/Screens/AvailableMeetingScreen.dart';
import 'package:mcd_attendance/Screens/LoginScreen.dart';
import 'package:mcd_attendance/Screens/Widgets/DialogBox.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Helpers/ApiBaseHelper.dart';

class SettingScreen extends StatefulWidget {
  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  bool _isLoading = false;
  String userName = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    getUserData();
  }

  getUserData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name')!;
    });
    print(userName);
  }

  Future<void> _clearPreference() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.clear();
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

  Future<void> getDeviceDeRegistrationStatus(String loginId, String deviceId) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 1)); // simulate delay

    var parameter = {
      "loginId": loginId,
      "deviceId": deviceId,
    };

    try {
      final getData = await apiBaseHelper.postAPICall(deviceDeRegistrationApi, parameter);
      final String error = getData['error'].toString();
      final String status = getData['status'].toString();

      print("API Response: $getData");

      if (!mounted) return;

      if (status == 'TRUE') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Device de-registered successfully.")),
        );

        if (Platform.isAndroid) {
          FlutterExitApp.exitApp();
        } else {
          FlutterExitApp.exitApp(iosForceExit: true);
        }
      } else if (error == 'NO RECORD FOUND.') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No record found for device or employee.")),
        );
      } else {
        _showNullValueError("getDe-registration Api: Error: $error");
      }
    } catch (e) {
      if (!mounted) return;
      _showNullValueError("getDe-registration Api: Error: ${e.toString()}");
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Settings",
                style: TextStyle(
                  fontSize: 24.sp, // Responsive font size
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(thickness: 0.3,color: Colors.black,),
              const SizedBox(
                height: 20,
              ),
              Container(
                alignment: Alignment.center,
                  child: Text(
                "Hello! $userName",
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink),
              )),
              const SizedBox(
                height: 20,
              ),
              // Container(
              //   width: double.infinity,
              //   padding: const EdgeInsets.symmetric(horizontal: 10),
              //   child: ElevatedButton(
              //     onPressed: () {
              //       showDialog(
              //         barrierDismissible: true,
              //         context: context,
              //         builder: (_) => const LogoutConfirmationDialog(),
              //       );
              //     },
              //     style: ElevatedButton.styleFrom(
              //       padding: EdgeInsets.symmetric(vertical: 15.h),
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(10),
              //       ),
              //       backgroundColor: const Color(0xff111184),
              //     ),
              //     child: const Text(
              //       "Logout",
              //       style: TextStyle(color: Colors.white),
              //     ),
              //   ),
              // ),
              // const SizedBox(
              //   height: 20,
              // ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ElevatedButton(
                  onPressed: () {
                    getDeviceDeRegistrationStatus(userBmid, deviceUniqueId);
                    _clearPreference();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: const Color(0xff111184),
                  ),
                  child: (_isLoading)
                      ? const Center(
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          "Deregister Device",
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
