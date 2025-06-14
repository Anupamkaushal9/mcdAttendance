import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mcd_attendance/Screens/LayoutScreen.dart';
import 'package:mcd_attendance/Screens/NewLayoutScreen.dart';
import 'package:mcd_attendance/Screens/Widgets/DialogBox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/String.dart';
import '../Model/Employee.dart';
import 'Widgets/GlassAppbar.dart';

class LoginScreen extends StatefulWidget {
  final bool isLoggingOut; // Flag to indicate if it's a logout navigation
  const LoginScreen({super.key, required this.isLoggingOut});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final bmidController = TextEditingController();
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<EmpData> empData = [];
  String? bmid;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isLoggingOut && bmid != null) {
      getEmpByBmid();
    }
  }

  Future<void> requestPermissions(BuildContext context) async {
    // Request permissions for camera, storage, and photos
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      Permission.photos,
      Permission.location
    ].request();

    // Check the status of each permission
    PermissionStatus? statusCamera = statuses[Permission.camera];
    PermissionStatus? statusStorage = statuses[Permission.storage];
    PermissionStatus? statusLocation = statuses[Permission.location];
    // Handle camera permission status
    if (statusCamera != PermissionStatus.granted) {
      if (statusCamera == PermissionStatus.denied) {
        print('Camera permission denied');
      } else if (statusCamera == PermissionStatus.permanentlyDenied) {
        print('Camera permission permanently denied');
        // Show dialog that cannot be dismissed until user opens settings
        showOpenSettingsDialog(context, "Camera");
      }

    }
    else
    {

    }

    if (statusLocation != PermissionStatus.granted) {
      if (statusLocation == PermissionStatus.denied) {
        print('Location permission denied');
      } else if (statusLocation == PermissionStatus.permanentlyDenied) {
        print('Location permission permanently denied');
        // Show dialog that cannot be dismissed until user opens settings
        showOpenSettingsDialog(context, "Location");
      }

    }
    else
    {

    }

    // Handle other permissions like storage
    if (statusStorage != PermissionStatus.granted) {
      if (statusStorage == PermissionStatus.denied) {
        print('Storage permission denied');
      } else if (statusStorage == PermissionStatus.permanentlyDenied) {
        print('Storage permission permanently denied');
        // Show dialog that cannot be dismissed until user opens settings
        showOpenSettingsDialog(context, "Storage");
      }
    }
    else
    {

    }
  }

  void showOpenSettingsDialog(BuildContext context, String permissionName) {
    showDialog(
      context: context,
      barrierDismissible: false,  // Prevent dismissal by tapping outside
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Text('Permission Required'),
            content: Text(
              'The $permissionName permission has been permanently denied. '
                  'Please enable it from the app settings to continue.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  // Open the app settings page
                  await openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      },
    );
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

  Future<void> _setBmidSharedPrefrence() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    print('bid = $bmid');
    await prefs.setString('user_bmid', bmid!);
    await prefs.setString('user_name', empName!);

    if (mounted) {
      setState(() {
        userBmid = prefs.getString('user_bmid')!;
      });
    }
    print('userBmid = $userBmid');
    print("userName = ${prefs.getString('user_name')!}");
  }

  Future<void> _setEmpDataSharedPrefrence(List<EmpData> data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    print('empData = $empData');
    // Convert list to a JSON string
    String jsonString = jsonEncode(data);
    String? getJsonString = '';
    await prefs.setString('employeeData', jsonString);

    if (mounted) {
      setState(() {
        getJsonString = prefs.getString('employeeData')!;
      });
    }
    print('employeeData>>>> = $getJsonString');
  }

  Future<void> apiLoginRequest() async {
    // Set loading state to true to show the progress indicator
    isLoading = true;
    if (mounted) setState(() {});

    var parameters = {
      "loginId": bmidController.text,
      "deviceId": deviceUniqueId,
    };

    try {
      // Call the API using your helper
      var response = await apiBaseHelper.postAPICall(loginApi, parameters);

      // Check if the response is valid
      if (response != null) {
        String status = response['status']?.toString() ?? '';
        String message = response['message']?.toString() ?? '';
        String error = response['error']?.toString() ?? '';

        print("API Response: $response");

        if (status == 'TRUE') {
          // Handle success
          await _setBmidSharedPrefrence();
          getEmpByBmid();
          getEmpFaceData().then((_) {
            _setEmpDataSharedPrefrence(empData);
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }

            if (mounted) {
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
                          Text(
                            "Login Success",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10.h, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              setState(() {
                empTempData = empData;
              });

              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await Future.delayed(const Duration(seconds: 2));

                if (!mounted) return;

                Navigator.of(context, rootNavigator: true).pop();

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => LayoutScreen(
                      bmid: userBmid,
                      empData: empTempData,
                    ),
                  ),
                      (Route<dynamic> route) => false,
                );
              });
            }
          }).catchError((e) {
            print("Cannot navigate because: $e");
            _showNullValueError("getFaceData Api:Failed to fetch face data. Please try again.");
          });
        } else {
          // Handle failure
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (_) => WillPopScope(
              onWillPop: () async => false,
              child: DeviceAlreadyAssignedDialog(text: error.toString()),
            ),
          );
        }
      } else {
        // Null response case
        _showNullValueError("Failed to communicate with the server. Please try again.");
      }
    } catch (e) {
      // Exception handling
      print("Error during API request: $e");
      _showNullValueError("$e An unexpected error occurred. Please try again.");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  Future<void> getEmpByBmid() async {
    if (mounted) {
      setState(() {
        isLoading = true; // Set loading to true when API call starts
      });
    }

    await Future.delayed(const Duration(seconds: 1)); // Simulate delay

    var parameter = {
      "orgGuid": "15f5e483-42e2-48ea-ab76-a4e26a20011c",
      "loginId": userBmid,
    };

    try {
      var getData = await apiBaseHelper.postAPICall(getEmpApi, parameter);

      String error = getData['error'].toString();
      String? msg = getData['status'].toString();

      print("API Response: $getData"); // Debugging line

      if (msg == 'TRUE') {
        var data = getData['employeeXML'];
        if (mounted) {
          setState(() {
            empData = [EmpData.fromJson(data)];
            userBmid = empData[0].loginId!;
            empGuid = empData[0].empGuid!;
            empName = empData[0].empName!;
            print("empGuid: ${empData[0].empGuid!}");
            _setBmidSharedPrefrence();
          });
        }
      } else {
        // API returned an error
        _showNullValueError("getEmpByBmid Api: $error $msg");

        if (mounted) {
          _clearPreference();
        }
      }
    } catch (e) {
      // API threw an exception
      _showNullValueError("getEmpByBmid Api: $e An unexpected error occurred while fetching employee data.");
    } finally {
      // Ensure loading indicator is hidden after the API call is complete
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  saveUserFaceData(String userFaceData) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_face_data', userFaceData);
  }

  Future<void> getEmpFaceData() async {
    print("load faceData");

    if (mounted) {
      setState(() {
        isLoading = true; // Set loading to true when API call starts
      });
    }

    await Future.delayed(const Duration(seconds: 1)); // Simulate network latency

    var parameter = {
      "bmid": bmidController.text,
    };

    try {
      var getData = await apiBaseHelper.postAPICall(
        Uri.parse('http://14.194.153.5/prod/api/attendance_testing/emp-face-data'),
        parameter,
      );

      String error = getData['error'].toString();
      String? msg = getData['status'].toString();
      print("API Response: $getData");

      if (msg == 'TRUE') {
        var data = getData['msg'];

        String efmImg = data['efm_img']; // Base64 encoded image
        String efmPath = data['efm_path']; // Image path
        String remarks = data['efm_remarks'] ?? 'No remarks';

        saveUserFaceData(efmImg); // Save image data

        print('Base64 Image: $efmImg');
        print('Image Path: $efmPath');

      } else {
        // API responded with status != TRUE
        String errorMsg = error.isNotEmpty
            ? error
            : 'An error occurred while fetching face data.';
        _showNullValueError("getFaceData Api: $errorMsg $msg");
      }
    } catch (e) {
      // Network or unexpected exception
      print("Exception while fetching face data: $e");
      _showNullValueError("getFaceData Api: $e An unexpected error occurred while fetching face data.");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false; // Always reset loading state
        });
      }
    }
  }


  Future<bool> _clearPreference() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: 'MCD SMART', isLayoutScreen: true),
      body: Form(
        key: _formKey,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 100),
                child: TextFormField(
                  controller: bmidController,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please Enter BMID';
                    }
                    if (val.length != 8) {
                      return 'Please enter valid 8 digit BMID.';
                    }
                    return null;
                  },
                  onSaved: (String? value) {
                    setState(() {
                      bmid = bmidController.text;
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter BMID',
                  ),
                ),
              ),
               SizedBox(height: 100.h),
              Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        apiLoginRequest();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 15.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: const Color(0xff111184),
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
                            'Submit',
                            style:
                                TextStyle(fontSize: 14.sp, color: Colors.white),
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
}
