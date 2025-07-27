import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Model/Employee.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/Constant.dart';
import '../Helpers/String.dart';
import 'UserProfileScreen.dart';
import 'Widgets/DialogBox.dart';

class SettingsScreenNew extends StatefulWidget {
  final List<EmpData> empData;
  const SettingsScreenNew({super.key, required this.empData});

  @override
  State<SettingsScreenNew> createState() => _SettingsScreenNewState();
}

class _SettingsScreenNewState extends State<SettingsScreenNew> {
  bool _isLoading = false;
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();

  // Show the loading dialog
  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent user from closing the dialog
      builder: (BuildContext context) {
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
                  repeat: true,
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
      },
    );
  }

  void _showRefreshDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent user from closing the dialog
      builder: (BuildContext context) {
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
                  repeat: true,
                ),
                SizedBox(height: 16.h),
                Text(
                  'Refreshing...',
                  style: TextStyle(fontSize: 16.sp),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  void _showDeregisterConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent user from closing the dialog
      builder: (BuildContext context) {
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
                width: 200.w,
                height: 200.h,
                repeat: false,
              ),
              const SizedBox(height: 16),
               Text(
                "Are you sure you want to de-register?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
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
                   SizedBox(width: 10.w,),
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
                          Navigator.pop(context); // Close the current screen
                          getDeviceDeRegistrationStatus(userBmid, deviceUniqueId);
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
      },
    );
  }

  saveUserFaceData(String userFaceData) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_face_data', userFaceData);
  }

  Future<void> getEmpFaceData() async {
    _showRefreshDialog(context);

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final Map<String, dynamic> parameter = {
      "bmid": userBmid,
    };

    try {
      final Uri url = Uri.parse('${baseUrl}emp-face-data');
      final Map<String, dynamic> getData = await apiBaseHelper.postAPICall(url, parameter);

      debugPrint("API Response (getEmpFaceData): $getData");

      final String status = getData['status']?.toString() ?? 'FALSE';
      final String error = getData['error']?.toString() ?? 'Unknown error';

      if (status == 'TRUE') {
        final data = getData['msg'];
        final String efmImg = data['efm_img'] ?? '';
        final String efmPath = data['efm_path'] ?? '';
        final String remarks = data['efm_remarks'] ?? 'No remarks';

        if (efmImg.isNotEmpty) {
          await prefs.setString('user_face_data', efmImg);

          debugPrint('Base64 Image Saved: $efmImg');
          debugPrint('Image Path: $efmPath');

          String? base64Image = prefs.getString('user_face_data');

          if (base64Image != null && base64Image.isNotEmpty) {
            const String prefix = 'data:image/jpeg;base64,';

            if (base64Image.startsWith(prefix)) {
              base64Image = base64Image.replaceFirst(prefix, '');
            }

            try {
              final Uint8List decodedImage = base64Decode(base64Image);
              if (decodedImage.isNotEmpty) {
                userPhoto = decodedImage;
                if (mounted) Navigator.pop(context);
              } else {
                if (mounted) Navigator.pop(context);
                _showNullValueError("Decoded image is empty.");
                userPhoto = null;
              }
            } catch (e) {
              if (mounted) Navigator.pop(context);
              _showNullValueError("Failed to decode image data: ${e.toString()}");
              userPhoto = null;
            }
          } else {
            if (mounted) Navigator.pop(context);
            _showNullValueError("No face data found in local storage.");
            userPhoto = null;
          }
        } else {
          if (mounted) Navigator.pop(context);
          _showNoFaceFound("No face data found on server!");
          userPhoto = null;
        }
      } else {
        if (mounted) Navigator.pop(context);
        _showNoFaceFound(error);
        userPhoto = null;
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showNullValueError('getEmpFaceData (exception): ${e.toString()}');
      userPhoto = null;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // ✅ Show "Refresh Complete" Dialog here
        _showRefreshCompleteDialog(context);
      }
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

  void _showRefreshCompleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          contentPadding: const EdgeInsets.all(20),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Refresh Done',
                style: TextStyle(fontSize: 20.sp,fontWeight: FontWeight.bold,color:Colors.blueAccent),
              ),
              const SizedBox(height:10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff111184),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Okay',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      )
    );
  }

  void _showNoFaceFound(String errorDetails) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Center(
                 child: Text(
                  errorDetails=='No enrollment data found.'?'No face enrollment data found':errorDetails,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                               ),
               ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff111184),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Okay',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }




  void _showDeRegisterDoneDialog() {
    if (mounted) {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (_) => WillPopScope(
          onWillPop: () async => false,
          child: const DeRegisterSuccessDialog(),
        ),
      );
    }
  }

  Future<void> getDeviceDeRegistrationStatus(String loginId, String deviceId) async {
    // Show loading dialog
    _showLoadingDialog(context);

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    await Future.delayed(const Duration(seconds: 1)); // Optional delay

    final parameter = {
      "loginId": loginId,
      "deviceId": deviceId,
    };

    try {
      final getData = await apiBaseHelper.postAPICall(deviceDeRegistrationApi, parameter);

      final String error = getData['error']?.toString() ?? '';
      final String status = getData['status']?.toString() ?? '';

      debugPrint("API Response: $getData");

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      if (status == 'TRUE') {
        _showDeRegisterDoneDialog();
      } else if (error == 'NO RECORD FOUND.') {
        _showNullValueError("getDeviceDeRegistrationStatus: No record found for device or employee.");
      } else {
        _showNullValueError("getDeviceDeRegistrationStatus: $error $status");
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Ensure loading dialog is closed on error
      }
      _showNullValueError("getDeviceDeRegistrationStatus Exception: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  Future<void> _clearPreference() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildSectionHeader('Account'),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                color: Colors.grey.shade200,
                shadowColor: Colors.teal,
                elevation: 5,
                child: Column(
                  children: [
                    _buildSettingItem(context, 'My Profile', Icons.person),
                  ],
                ),
              ),
            ),
            _buildSectionHeader('Support & About'),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                color: Colors.grey.shade200,
                shadowColor: Colors.teal,
                elevation: 5,
                child: Column(
                  children: [
                    _buildSettingItem(
                        context, 'My App Version', Icons.app_settings_alt),
                  ],
                ),
              ),
            ),
            _buildSectionHeader('Actions'),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                color: Colors.grey.shade200,
                shadowColor: Colors.teal,
                elevation: 5,
                child: Column(
                  children: [
                    _buildSettingItem(context, 'Refresh Data',
                        Icons.refresh),
                    _buildDivider(),
                    _buildSettingItem(context, 'De-Register your device',
                        Icons.device_unknown),
                    _buildDivider(),
                    _buildSettingItem(
                      context,
                      'Log out',
                      Icons.logout,
                      textColor: Colors.red,
                      iconColor: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Text(
        title,
        style:  TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: Colors.black45,
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    String title,
    IconData icon, {
    Color textColor = Colors.black,
    Color iconColor = const Color(0xff111184),
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(color: textColor),
      ),
      onTap: () {
        if (title == 'My Profile') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProfileScreen(),
            ),
          );
        }
        if (title == 'Refresh Data') {
          getEmpFaceData();
        }
        if (title == 'Log out') {
          showDialog(
            barrierDismissible: true,
            context: context,
            builder: (_) => const LogoutConfirmationDialog(),
          );
        }
        if (title == 'De-Register your device') {
          _showDeregisterConfirmDialog(context);
        }
        if (title == 'My App Version') {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              contentPadding: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LottieBuilder.asset(
                    'assets/animations/app_version.json', // Provide the correct asset path
                    repeat: false,
                  ),
                   SizedBox(height: 16.h),
                   Text(
                    'Current App Version',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                   SizedBox(height: 8.h),
                  Text(
                    appVersionFromDevice,
                    style:  TextStyle(
                      fontSize: 18.sp,
                      color: Colors.black,
                    ),
                  ),
                   SizedBox(height: 24.h),
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
      },
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16);
  }
}
