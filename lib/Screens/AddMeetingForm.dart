import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:mcd_attendance/Helpers/Constant.dart';
import 'package:mcd_attendance/Screens/NewAvailableMeetingScreen.dart';
import 'package:mcd_attendance/Screens/Widgets/GlassAppbar.dart';
import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/NotificationService.dart';
import '../Helpers/String.dart';
import 'package:timezone/timezone.dart' as tz;
import 'Widgets/DialogBox.dart';

class AddMeetingFormScreen extends StatefulWidget {
  final Function(BuildContext) onFormSubmit;
  const AddMeetingFormScreen({super.key, required this.onFormSubmit});

  @override
  State<AddMeetingFormScreen> createState() => _AddMeetingFormScreenState();
}

class _AddMeetingFormScreenState extends State<AddMeetingFormScreen> {
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  bool isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers for the form fields
  final meetingNameController = TextEditingController();
  final meetingDateController = TextEditingController();
  final meetingTimeController = TextEditingController();
  final notesController = TextEditingController();

  @override
  void initState() {
    _checkInternetAndInitialize();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    meetingNameController.dispose();
    meetingDateController.dispose();
    meetingTimeController.dispose();
    notesController.dispose();
  }

  Future<void> _checkInternetAndInitialize() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return NoInternetDialog(
            onRetry: () {
              (Platform.isAndroid) ? FlutterExitApp.exitApp() : FlutterExitApp.exitApp(iosForceExit: true);
            },
          );
        },
      );
      return;
    }
  }

  Future<void> addMeeting(BuildContext context) async {
    setState(() {
      isLoading = true;
    });

    const url = newBaseUrl;
    const String token = 'eyJhbGciOiJIUzI1NiJ9.e30.g2PzdcLXSunm0_ZW-5d9ptZSpeXZi0qsh_sTuTTojRs';

    final Map<String, dynamic> requestBody = {
      "module": "meeting",
      "event": "add",
      "params": {
        "meeting_title": meetingNameController.text,
        "meeting_date": meetingDateController.text,
        "meeting_time": meetingTimeController.text,
        "meeting_description": notesController.text,
        "emp_bmid": userBmid
      }
    };

    try {
      var response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint('Success Response: ${responseData.toString()}');

        // Schedule notifications
        DateTime meetingDate = DateFormat('yyyy-MM-dd').parse(meetingDateController.text);
        List<String> timeParts = meetingTimeController.text.split(':');
        DateTime meetingDateTime = DateTime(
          meetingDate.year,
          meetingDate.month,
          meetingDate.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );

        tz.TZDateTime scheduledDateTime30min = tz.TZDateTime.from(
            meetingDateTime.subtract(const Duration(minutes: 30)),
            tz.local
        );
        tz.TZDateTime scheduledDateTime10min = tz.TZDateTime.from(
            meetingDateTime.subtract(const Duration(minutes: 10)),
            tz.local
        );

        NotificationService.scheduleNotification(
            DateTime.now().millisecondsSinceEpoch % 100000000,
            'Meeting Reminder',
            'Your meeting "${meetingNameController.text}" will start in 30 minutes.',
            scheduledDateTime30min,
            meetingNameController.text
        );

        NotificationService.scheduleNotification(
            (DateTime.now().millisecondsSinceEpoch % 100000000) + 1,
            'Meeting Reminder',
            'Your meeting "${meetingNameController.text}" will start in 10 minutes.',
            scheduledDateTime10min,
            meetingNameController.text
        );
        Navigator.of(context).pop();
        _showDialog(context, 'Meeting Added!', 'Your meeting has been scheduled.', Colors.green);
      } else {
        debugPrint('Failed Response: ${response.body}');
        _showDialog(context, 'Failed to Add Meeting', response.body, Colors.red);
      }
    } catch (e) {
      debugPrint('Error: $e');
      _showDialog(context, 'Error', e.toString(), Colors.red);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showDialog(BuildContext context, String title, String message, Color color) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(
            child: Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                color == Colors.green ? Icons.check_circle : Icons.error,
                color: color,
                size: 50,
              ),
              SizedBox(height: 10.h),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
          actions: <Widget>[
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
                  Navigator.of(context).pop();
                  widget.onFormSubmit(context);
                },
                child: Text(
                  "Okay",
                  style: TextStyle(fontSize: 16.sp, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xff111184),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff111184),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        meetingDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
      // No longer automatically opens time picker
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    if (meetingDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date first')));
      return;
    }

    final selectedDate = DateFormat('yyyy-MM-dd').parse(meetingDateController.text);
    final currentTime = TimeOfDay.now();
    final now = DateTime.now();

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentTime.hour + 1,
        minute: currentTime.minute,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xff111184),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        picked.hour,
        picked.minute,
      );

      // Only validate time if the selected date is today
      if (selectedDate.year == now.year &&
          selectedDate.month == now.month &&
          selectedDate.day == now.day) {
        if (selectedDateTime.isBefore(now)) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Center(child: Text('Invalid Time')),
              content: const Text(
                  'For today, you cannot select a time in the past. Please select a future time.'),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff111184),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Ok",
                      style: TextStyle(fontSize: 16.sp, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
          return;
        }
      }

      String formattedTime = "${picked.hour.toString().padLeft(2, '0')}:"
          "${picked.minute.toString().padLeft(2, '0')}";
      setState(() {
        meetingTimeController.text = formattedTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GlassAppBar(title: 'MCD PRO', isLayoutScreen: false),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: meetingNameController,
                    decoration: InputDecoration(
                      labelText: 'Meeting title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 14.h, horizontal: 16.w),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the meeting name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: meetingDateController,
                          decoration: InputDecoration(
                            labelText: 'Date of meeting',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 14.h, horizontal: 16.w),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                          onTap: () => _selectDate(context),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: TextFormField(
                          controller: meetingTimeController,
                          decoration: InputDecoration(
                            labelText: 'Time of meeting',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 14.h, horizontal: 16.w),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                          onTap: () => _selectTime(context),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  TextFormField(
                    controller: notesController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Enter additional notes',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 14.h, horizontal: 16.w),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter some notes';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20.h),
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          addMeeting(context);
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
                          ? Center(
                        child: SizedBox(
                          height: 20.h,
                          width: 20.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      )
                          : Text('Add Meeting',
                          style: TextStyle(
                              fontSize: 14.sp, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}