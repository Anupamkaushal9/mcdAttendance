import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Screens/DeviceRegistrationScreen.dart';
import 'package:mcd_attendance/Screens/LayoutScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/AppBtn.dart';
import '../Helpers/Session.dart';
import '../Helpers/String.dart';
import '../Model/Employee.dart';
import 'LoginScreen.dart';
import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen>
    with TickerProviderStateMixin {
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<EmpData> empData = [];
  bool _isNetworkAvail = true;
  bool isLoading = false;
  bool _isLoading = false;
  bool isUserFound = false; // Flag to control user data visibility
  bool isButtonTapped = false;
  final _formKey = GlobalKey<FormState>();
  final bmidController = TextEditingController();

  @override
  void initState() {
    bmidController.addListener(() {
      setState(() {}); // Trigger a rebuild to update the button state
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
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

  Future<void> searchEmpByBmid() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        isUserFound = false;
      });
    }

    FocusScope.of(context).unfocus(); // Close keyboard

    await Future.delayed(const Duration(seconds: 1));

    var parameter = {
      "orgGuid": "15f5e483-42e2-48ea-ab76-a4e26a20011c",
      "loginId": bmidController.text,
    };

    await apiBaseHelper.postAPICall(getEmpApi, parameter).then((getData) {
      String error = getData['error'].toString();
      String? status = getData['status'].toString();

      print("API Response (searchEmpByBmid): $getData");

      if (status == 'TRUE') {
        var data = getData['employeeXML'];

        if (mounted) {
          setState(() {
            empData = [EmpData.fromJson(data)];
            userBmid = empData[0].loginId!;
            empGuid = empData[0].empGuid!;
            empName = empData[0].empName!;
            isUserFound = true;
            bmidController.clear();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isUserFound = false;
            isButtonTapped = true;
          });
          if(!error.contains('does not exist'))
            {
          _showNullValueError('searchEmpByBmid: $error $status');
            }
        }
      }
    }, onError: (e) {
      if (mounted) {
        _showNullValueError('searchEmpByBmid (onError): ${e.toString()}');
      }
    }).whenComplete(() {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }


  saveUserFaceData(String userFaceData) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_face_data', userFaceData);
  }

  Future<void> _setEmpDataSharedPrefrence(List<EmpData> data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String jsonString = jsonEncode(data);
    String? getJsonString = '';
    await prefs.setString('employeeData', jsonString);

    if (mounted) {
      setState(() {
        empTempData = empData;
        getJsonString = prefs.getString('employeeData')!;
      });
    }
    print('employeeData>>>> = $getJsonString');
  }

  Future<void> getEmpFaceData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    await Future.delayed(const Duration(seconds: 1));

    var parameter = {
      "bmid": userBmid,
    };

    await apiBaseHelper
        .postAPICall(
      Uri.parse('http://14.194.153.5/prod/api/attendance_testing/emp-face-data'),
      parameter,
    )
        .then((getData) {
      String error = getData['error'].toString();
      String? msg = getData['status'].toString();

      print("API Response (getEmpFaceData): $getData");

      if (msg == 'TRUE') {
        var data = getData['msg'];

        String efmImg = data['efm_img'];
        String efmPath = data['efm_path'];
        String remarks = data['efm_remarks'] ?? 'No remarks';

        saveUserFaceData(efmImg);

        // Success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => WillPopScope(
            onWillPop: () async => false,
            child: Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LottieBuilder.asset(
                      'assets/animations/success_animation.json',
                      width: 30.w,
                      height: 30.h,
                      repeat: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Navigate after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          Navigator.of(context).pop();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => LayoutScreen(bmid: userBmid, empData: empData),
            ),
                (Route<dynamic> route) => false,
          );
        });

        print('Base64 Image: $efmImg');
        print('Image Path: $efmPath');
      } else {
        String errorMsg = getData['error'] ?? 'An error occurred while fetching face data.';

        if (errorMsg == 'No enrollment data found.') {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => LayoutScreen(bmid: userBmid, empData: empData),
            ),
                (Route<dynamic> route) => false,
          );
        } else {
          _showNullValueError('getEmpFaceData: $errorMsg $msg');
        }
      }
    }, onError: (e) {
      if (mounted) {
        _showNullValueError('getEmpFaceData (onError): ${e.toString()}');
      }
    }).whenComplete(() {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      var payload = {
        "empGuid": empGuid,
        "deviceId": deviceId,
        "orgGuid": orgGuid,
      };

      await apiBaseHelper.postAPICall(deviceRegistrationApi, payload).then((responseData) {
        String error = responseData['error'] ?? '';
        String status = responseData['status'] ?? '';

        if (status == 'TRUE') {
          var message = responseData['message'] ?? 'Device registered successfully';

          // Show success dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => WillPopScope(
              onWillPop: () async => false,
              child: Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          // Close the dialog after 1 second
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.of(context).pop();
          });

          _setBmidSharedPrefrence();
          _setEmpDataSharedPrefrence(empData);

          getEmpFaceData().then((_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }

            // Optional navigation block
            // Navigator.of(context).pushAndRemoveUntil(
            //   MaterialPageRoute(
            //     builder: (context) => LayoutScreen(bmid: userBmid, empData: empData),
            //   ),
            //   (Route<dynamic> route) => false,
            // );
          }).catchError((e) {
            _showNullValueError('registerDevice (getEmpFaceData error): ${e.toString()}');
          });
        } else if (error == 'DEVICE ALREADY REGISTERED.') {
          _showNullValueError('registerDevice: DEVICE ALREADY REGISTERED.');
        } else {
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (_) => const DeviceAlreadyRegisteredDialog(),
          );
        }
      }).catchError((error) {
        _showNullValueError('registerDevice (catchError): ${error.toString()}');
      }).whenComplete(() {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (error) {
      _showNullValueError('registerDevice (try-catch): ${error.toString()}');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GlassAppBar(title: 'MCD SMART', isLayoutScreen: true),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
                child: TextFormField(
                  controller: bmidController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 8,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please Enter BMID';
                    }
                    if (val.length != 8) {
                      return 'Please enter valid 8 digit BMID.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter BMID to search the user',
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ElevatedButton(
                    onPressed: bmidController.text.isEmpty
                        ? null // Disable button if BMID is empty
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();
                              searchEmpByBmid(); // Call the method after setting the BMID
                              FocusScope.of(context).unfocus();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 15.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: bmidController.text.isEmpty
                          ? Colors.grey // Disabled color
                          : const Color(0xff111184), // Enabled color
                    ),
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
                        : Text(
                            'Search',
                            style:
                                TextStyle(fontSize: 14.sp, color: Colors.white),
                          ),
                  ),
                ),
              ),
               SizedBox(
                height: 20.h,
              ),
              (isUserFound)? // Show user details card if user is found
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     Text(
                      'User Found',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                          fontSize: 15.sp),
                    ),
                     SizedBox(
                      height: 10.h,
                    ),
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
                                value: empData.first.empId ?? ""),
                            const Divider(),
                            UserInfoRow(
                                label: "Name",
                                value: empData.first.empName ?? ""),
                            const Divider(),
                            UserInfoRow(
                                label: "Email",
                                value: empData.first.email ?? ""),
                            const Divider(),
                            UserInfoRow(
                                label: "Mobile",
                                value: empData.first.mobile ?? ""),
                            const Divider(),
                            UserInfoRow(
                                label: "Designation",
                                value: empData.first.empDesignation ?? ""),
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
                                style: TextStyle(
                                    fontSize: 14.sp, color: Colors.white)),
                      ),
                    ),
                  ],
                ):Center(child: (isButtonTapped)? Text(
                'User Not Found',
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                    fontSize: 15.sp),
              ):const Text(''),),



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
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }
}
