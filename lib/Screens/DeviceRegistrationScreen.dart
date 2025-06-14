import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Screens/LayoutScreen.dart';
import 'package:mcd_attendance/Screens/LoginScreen.dart';
import 'package:mcd_attendance/Screens/MenuScreen.dart';
import 'package:mcd_attendance/Screens/NewLayoutScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/String.dart';
import '../Model/Employee.dart';
import 'Widgets/DialogBox.dart';

class DeviceRegistrationScreen extends StatefulWidget {
  final List<EmpData> empData;

  const DeviceRegistrationScreen({
    super.key,
    required this.empData,
  });

  @override
  _DeviceRegistrationScreenState createState() =>
      _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Delay scrolling to ensure the widgets are fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  saveUserFaceData(String userFaceData) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_face_data', userFaceData);
  }

  Future<void> _setEmpDataSharedPrefrence(List<EmpData> data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    print('empData = $widget.empData');
    // Convert list to a JSON string
    String jsonString = jsonEncode(data);
    String? getJsonString = '';
    await prefs.setString('employeeData', jsonString);

    if (mounted) {
      setState(() {
        empTempData = widget.empData;
        getJsonString = prefs.getString('employeeData')!;
      });
    }
    print('employeeData>>>> = $getJsonString');
  }

  Future<void> getEmpFaceData() async {
    setState(() {
      _isLoading = true; // Set loading to true when API call starts
    });

    // Simulate network latency
    await Future.delayed(const Duration(seconds: 1));

    // Prepare the parameters for the API call
    var parameter = {
      "bmid": userBmid, // Employee BMID or empGuid
    };

    await apiBaseHelper
        .postAPICall(
            Uri.parse(
                'http://14.194.153.5/prod/api/attendance_testing/emp-face-data'),
            parameter)
        .then((getData) {
      String error = getData['error'].toString();
      String? msg = getData['status'].toString();
      print("API Response: $getData");

      if (msg == 'TRUE') {
        var data = getData['msg'];

        String efmImg = data['efm_img']; // Base64 encoded image
        String efmPath = data['efm_path']; // Image path
        String remarks = data['efm_remarks'] ?? 'No remarks';

        saveUserFaceData(efmImg); // Saving userPhotoData to SharedPreferences

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Face data fetched successfully. Remarks: $remarks')),
        );

        print('Base64 Image: $efmImg');
        print('Image Path: $efmPath');

        // After both APIs are successful, navigate to the LayoutScreen
        if (mounted) {
          setState(() {
            _isLoading = false; // Set loading to false after fetching face data
          });
        }
      } else {
        String errorMsg =
            getData['error'] ?? 'An error occurred while fetching face data.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $errorMsg")),
        );
        setState(() {
          _isLoading = false; // Set loading to false if face data fetch failed
        });
      }
    }, onError: (e) {
      if (mounted) {
        setState(() {
          _isLoading = false; // Set loading to false if error occurs
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }).whenComplete(() {
      if (mounted) {
        setState(() {
          _isLoading = false; // Ensure loading is false when the API completes
        });
      }
    });
  }

  Future<void> _setBmidSharedPrefrence() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_bmid', userBmid!);
    await prefs.setString('user_name', empName!);

    if (mounted) {
      setState(() {
        userBmid = prefs.getString('user_bmid')!;
      });
    }
    print('userBmid = $userBmid');
    print("userName = $prefs.getString('user_name')!");
  }

  registerDevice(String empGuid, String deviceId, String orgGuid) async {
    try {
      // Show loading indicator (optional)
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Prepare the payload (input)
      var payload = {
        "empGuid": empGuid,
        "deviceId": deviceId,
        "orgGuid": orgGuid,
      };

      // Make the API request using apiBaseHelper
      await apiBaseHelper
          .postAPICall(deviceRegistrationApi, payload)
          .then((responseData) {
        String error = responseData['error'] ?? '';
        String status = responseData['status'] ?? '';

        // Handle response based on status and error
        if (status == 'TRUE') {
          // Success case: Device registration successful
          var message =
              responseData['message'] ?? 'Device registered successfully';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );

          // If needed, navigate to another screen or perform other actions
          // For example, you could exit the app after 1 second:
          _setBmidSharedPrefrence();
          _setEmpDataSharedPrefrence(widget.empData);
          getEmpFaceData().then((_) {
            // Ensure loading indicator is hidden after the API call is complete
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }

            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) =>  LayoutScreen(bmid: userBmid, empData: widget.empData),
              ),
                  (Route<dynamic> route) => false,
            );
          }).catchError((e) {
            print("Cannot navigate");
          });
        } else if (error == 'DEVICE ALREADY REGISTERED.') {
          // Handle case when device is already registered
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('DEVICE ALREADY REGISTERED.')),
          );
        } else if (error ==
            'DEVICE NOT APPROVED. PLEASE WAIT FOR ADMIN APPROVAL') {
          // Handle case when device is not approved
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'DEVICE NOT APPROVED. PLEASE WAIT FOR ADMIN APPROVAL')),
          );
        } else {
          // Handle other errors or generic failure cases
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (_) => const DeviceAlreadyRegisteredDialog(),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        }
      }).catchError((error) {
        // Catch any errors thrown by the API helper (e.g., network or response parsing errors)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${error.toString()}')),
        );
      });
    } catch (error) {
      // Catch any unexpected errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${error.toString()}')),
      );
    } finally {
      // Hide the loading indicator once the API call completes
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Device Registration',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                margin: EdgeInsets.symmetric(horizontal: 10.h),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      SizedBox(height: 20.h),
                      UserInfoRow(
                          label: "Employee ID",
                          value: widget.empData.first.empId ?? ""),
                      const Divider(),
                      UserInfoRow(
                          label: "Name",
                          value: widget.empData.first.empName ?? ""),
                      const Divider(),
                      UserInfoRow(
                          label: "Email",
                          value: widget.empData.first.email ?? ""),
                      const Divider(),
                      UserInfoRow(
                          label: "Mobile",
                          value: widget.empData.first.mobile ?? ""),
                      const Divider(),
                      UserInfoRow(
                          label: "Designation",
                          value: widget.empData.first.empDesignation ?? ""),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 20.h,
              ),
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 10.w),
                child: ElevatedButton(
                  onPressed: () {
                    registerDevice(empGuid, deviceUniqueId, orgGuid);
                    },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: const Color(0xff111184),
                  ),
                  child: (_isLoading)
                      ?  Center(
                          child: SizedBox(
                            height: 20.h,
                            width: 20.w,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Text('Register Device',
                          style:
                              TextStyle(fontSize: 14.sp, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const UserInfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style:  TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
          ),
          Flexible(
            child: Text(
              value,
              style:  TextStyle(fontSize: 16.sp),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
