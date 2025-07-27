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
import '../Helpers/Constant.dart';
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

      debugPrint("API Response (searchEmpByBmid): $getData");

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
          if (!error.contains('does not exist')) {
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
    debugPrint('employeeData>>>> = $getJsonString');
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
      Uri.parse('${baseUrl}emp-face-data'),
      parameter,
    )
        .then((getData) {
      String error = getData['error'].toString();
      String? msg = getData['status'].toString();

      debugPrint("API Response (getEmpFaceData): $getData");

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
              builder: (context) =>
                  LayoutScreen(bmid: userBmid, empData: empData),
            ),
            (Route<dynamic> route) => false,
          );
        });

        debugPrint('Base64 Image: $efmImg');
        debugPrint('Image Path: $efmPath');
      } else {
        String errorMsg =
            getData['error'] ?? 'An error occurred while fetching face data.';

        if (errorMsg == 'No enrollment data found.') {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) =>
                  LayoutScreen(bmid: userBmid, empData: empData),
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
    debugPrint('userBmid = $userBmid');
    debugPrint("userName = $prefs.getString('user_name')!");
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

      await apiBaseHelper
          .postAPICall(deviceRegistrationApi, payload)
          .then((responseData) {
        String error = responseData['error'] ?? '';
        String status = responseData['status'] ?? '';

        if (status == 'TRUE') {
          var message =
              responseData['message'] ?? 'Device registered successfully';

          // Show success dialog
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
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10.sp, fontWeight: FontWeight.bold),
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
            _showNullValueError(
                'registerDevice (getEmpFaceData error): ${e.toString()}');
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
      body: GestureDetector(
        onTap: (){
          FocusScope.of(context).unfocus();
        },
        child: Container(
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                 Color(0xff2a5aab),  // 20% darker
                 Color(0xff3e7dd5),  // Original color
                 Color(0xff6a9ae3),  // 20% lighter
              ],
            ),
          ),
          child: Form(
            key: _formKey,
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Header Section
                    Container(
                      padding: EdgeInsets.only(top: 30.h, bottom: 10.h),
                      child: Text(
                        'DEVICE REGISTRATION',
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    // Search Card
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Card(
                        color: Colors.white,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20.w),
                          child: Column(
                            children: [
                              Text(
                                'Search Employee',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              TextFormField(
                                controller: bmidController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                maxLength: 8,
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Please Enter BMID';
                                  }
                                  if (val.length != 8) {
                                    return 'Please enter valid 8 digit BMID';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.blue.shade400,
                                      width: 1.0,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.blue.shade400,
                                      width: 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.blue.shade700,
                                      width: 1.5,
                                    ),
                                  ),
                                  hintText: 'Enter 8-digit BMID',
                                  suffixIcon: isLoading
                                      ? Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Material(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                  10), // Adjust for more/less rounding
                                            ),
                                            color: const Color(
                                                0xff111184), // Light background color
                                            elevation: 0,
                                            child: Padding(
                                              padding: const EdgeInsets.all(10.0),
                                              child: SizedBox(
                                                width: 8.w,
                                                height: 8.h,
                                                child:
                                                    const CircularProgressIndicator(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Material(
                                            // Rounded square shape
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                  10), // Adjust for more/less rounding
                                            ),
                                            color: const Color(
                                                0xff111184), // Light background color
                                            elevation: 0, // No shadow by default
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(10),
                                              onTap: () async {
                                                if (_formKey.currentState!
                                                    .validate()) {
                                                  _formKey.currentState!.save();
                                                  searchEmpByBmid();
                                                  FocusScope.of(context).unfocus();
                                                }
                                              },
                                              child: Padding(
                                                padding: EdgeInsets.all(
                                                    8.w), // Adjust padding for size
                                                child: Icon(
                                                  Icons.search,
                                                  color: Colors.white,
                                                  size: 24.w, // Adjust icon size
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 16.h,
                                    horizontal: 16.w,
                                  ),
                                ),
                                onFieldSubmitted: (value) async {
                                  if (_formKey.currentState!.validate()) {
                                    _formKey.currentState!.save();
                                    searchEmpByBmid();
                                    FocusScope.of(context).unfocus();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Results Section
                    if (isUserFound) ...[
                      SizedBox(height: 15.h),
                      Text(
                        'Employee Found',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff00ff00),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          color: Colors.grey.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              children: [
                                UserInfoRow(
                                  label: "Employee ID",
                                  value: empData.first.empId ?? "",
                                ),
                                Divider(color: Colors.grey.shade300),
                                UserInfoRow(
                                  label: "Name",
                                  value: empData.first.empName ?? "",
                                ),
                                Divider(color: Colors.grey.shade300),
                                UserInfoRow(
                                  label: "Email",
                                  value: empData.first.email ?? "",
                                ),
                                Divider(color: Colors.grey.shade300),
                                UserInfoRow(
                                  label: "Mobile",
                                  value: empData.first.mobile ?? "",
                                ),
                                Divider(color: Colors.grey.shade300),
                                UserInfoRow(
                                  label: "Designation",
                                  value: empData.first.empDesignation ?? "",
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 30.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              registerDevice(empGuid, deviceUniqueId, orgGuid);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              backgroundColor: const Color(0xff111184),
                              elevation: 3,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20.h,
                                    width: 20.w,
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Register Device',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ] else if (isButtonTapped && !isLoading) ...[
                      SizedBox(height: 30.h),
                      Icon(
                        Icons.error_outline,
                        color: const Color(0xffFF3131),
                        size: 40.sp,
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        'User Not Found',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xffFF3131),
                        ),
                      ),
                    ] else if (isLoading) ...[
                      SizedBox(
                        height: 40.h,
                      ),
                      Center(
                        child: Text(
                          'Searching please wait.....',
                          style:
                              TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp,color: const Color(0xff31FFFF)),
                        ),
                      )
                    ]
                    else...[
                      SizedBox(height: 40.h,),
                      SizedBox(
                          child: Image.asset(
                            'assets/images/mcd-logo.png', // Replace with your image asset
                            height: 250.h,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UserInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final int? maxLines;
  final bool expandable;

  const UserInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.maxLines = 2,
    this.expandable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon if provided
          if (icon != null) ...[
            Icon(icon, size: 18.sp, color: Colors.blue.shade700),
            SizedBox(width: 8.w),
          ],

          // Label
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
              color: Colors.grey.shade700,
            ),
          ),

          // Value with flexible width
          Expanded(
            child: expandable
                ? ExpandableText(
                    value,
                    style: TextStyle(fontSize: 14.sp),
                    maxLines: maxLines!,
                    expandText: 'more',
                    collapseText: 'less',
                    linkColor: Colors.blue,
                  )
                : Text(
                    value,
                    style: TextStyle(fontSize: 14.sp),
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }
}

// For expandable text functionality (add this widget to your code)
class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final String expandText;
  final String collapseText;
  final Color linkColor;

  const ExpandableText(
    this.text, {
    super.key,
    this.maxLines = 2,
    this.style,
    this.expandText = 'Show more',
    this.collapseText = 'Show less',
    this.linkColor = Colors.blue,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: widget.style,
          maxLines: _isExpanded ? null : widget.maxLines,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.text.length > 50) // Only show toggle if text is long
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Text(
              _isExpanded ? widget.collapseText : widget.expandText,
              style: TextStyle(
                color: widget.linkColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
