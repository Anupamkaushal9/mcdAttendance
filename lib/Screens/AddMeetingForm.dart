import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // For responsive design
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
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

  // final DatabaseHelper _dbHelper = DatabaseHelper();

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
              (Platform.isAndroid)?FlutterExitApp.exitApp():FlutterExitApp.exitApp(iosForceExit: true);
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

    // API URL
    const url = 'https://api.mcd.gov.in/app/request';

    // Request body data
    final Map<String, dynamic> requestBody = {
      "module": "meeting",
      "event": "add",
      "params": {
        "meeting_title": meetingNameController.text,
        "meeting_date": meetingDateController.text,
        "meeting_time": meetingTimeController.text, // Use the correct time as per your requirement
        "meeting_description": notesController.text,
        "emp_bmid": userBmid
      }
    };

    // Authorization token (JWT)
    const String token = 'eyJhbGciOiJIUzI1NiJ9.e30.g2PzdcLXSunm0_ZW-5d9ptZSpeXZi0qsh_sTuTTojRs';

    // Create headers
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Attach Bearer token
    };

    // Debugging: Print headers to verify token inclusion
    print('Headers: $headers');

    // Create HTTP request
    var request = http.Request('POST', Uri.parse(url));

    // Set the body of the request
    request.body = json.encode(requestBody);

    // Add headers to the request
    request.headers.addAll(headers);

    try {
      // Send the request
      http.StreamedResponse response = await request.send();

      // Check if the response was successful
      if (response.statusCode == 200) {
        // Get the response body as a string
        String responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> responseData = json.decode(responseBody);

        // Print response message (success case)
        print('Success Response: ${responseData.toString()}');
        Navigator.of(context).pop();
        setState(() {
          isLoading = false;
        });

        // Show Success Dialog
        _showDialog(context, 'Meeting Added!', 'Your meeting has been scheduled.', Colors.green);
      } else {
        // If the response code is not 200, print the error response
        String errorResponse = await response.stream.bytesToString();

        // Print response message (failure case)
        print('Failed Response: $errorResponse');

        setState(() {
          isLoading = false;
        });

        // Show Failure Dialog
        _showDialog(context, 'Failed to Add Meeting', errorResponse, Colors.red);
      }
    } catch (e) {
      // Print error message (network or other issues)
      print('Error: $e');

      setState(() {
        isLoading = false;
      });

      // Show Failure Dialog
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
            SizedBox(width: double.infinity,
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
                child:  Text(
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
      initialDate: DateTime.now(), // Default to today's date
      firstDate: DateTime.now(), // First date that can be selected is tomorrow
      lastDate: DateTime(2101), // You can adjust the last date to be further in the future if needed
    );

    if (picked != null && picked != DateTime.now()) {
      setState(() {
        meetingDateController.text = '${picked.toLocal()}'
            .split(' ')[0]; // Display only the date in yyyy-MM-dd format
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    // Get the current time
    final currentTime = TimeOfDay.now();

    // Get the current DateTime for comparison (today's date)
    final now = DateTime.now();

    // Set the next available time (1 hour from the current time)
    final nextAvailableTime = TimeOfDay(
      hour: currentTime.hour + 1,
      minute: currentTime.minute,
    );

    // Show the time picker with the next available time as the initial time
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: nextAvailableTime, // Default to one hour ahead
    );

    if (picked != null) {
      int hour = picked.hour;
      int minute = picked.minute;

      // Create DateTime for the selected time
      final selectedTime = DateTime(now.year, now.month, now.day, hour, minute);

      // If the selected time is in the past for today, show a warning
      if (selectedTime.isBefore(now)) {
        // Show a dialog or a Snackbar to inform the user
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Center(child: Text('Invalid Time')),
            content: const Text(
                'You cannot select a time in the past for today. Please select a future time.'),
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
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child:  Text(
                    "Ok",
                    style: TextStyle(fontSize: 16.sp, color: Colors.white),
                  ),
                ),
              )
            ],
          ),
        );
        return; // Exit the function to prevent updating the time
      }

      // Format the hour and minute in "HH:mm" format (24-hour format)
      String formattedTime = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

      // Update the controller with the formatted time
      meetingTimeController.text = formattedTime;

      // Print the formatted time for debugging
      print("Formatted Time: $formattedTime");
    }
  }


  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GlassAppBar(title: 'MCD SMART', isLayoutScreen: false),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0.sp), // Spacing using ScreenUtil
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Form Fields
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Meeting Name Field
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
                      // Deadline Date
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
                      // Deadline Time
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
                          onTap: () {
                            _selectTime(context);
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Notes Field
                  TextFormField(
                    controller: notesController,
                    maxLines: 5, // Allow multiple lines for notes
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

                  // Add Button
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (){
                        if(_formKey.currentState!.validate())
                          {
                            addMeeting(context);
                            // Parse meeting date and time and combine them
                            DateTime meetingDate = DateFormat('yyyy-MM-dd').parse(meetingDateController.text);
                            List<String> timeParts = meetingTimeController.text.split(':');
                            int hour = int.parse(timeParts[0]);
                            int minute = int.parse(timeParts[1]);

                            // Combine the meeting date with the time to get a full DateTime object
                            DateTime meetingDateTime = DateTime(
                              meetingDate.year,
                              meetingDate.month,
                              meetingDate.day,
                              hour,
                              minute,
                            );
                            // Calculate the notification times
                            DateTime notificationDateTime30min = meetingDateTime.subtract(const Duration(minutes: 30));
                            DateTime notificationDateTime10min = meetingDateTime.subtract(const Duration(minutes: 10));

                            // Convert to TZDateTime (local timezone)
                            tz.TZDateTime scheduledDateTime30min = tz.TZDateTime.from(notificationDateTime30min, tz.local);
                            tz.TZDateTime scheduledDateTime10min = tz.TZDateTime.from(notificationDateTime10min, tz.local);

                             // Schedule the first notification (30 minutes before the meeting)
                            NotificationService.scheduleNotification(
                               DateTime.now().millisecondsSinceEpoch% 100000000,
                              'Meeting Reminder',
                              'Your meeting "${meetingNameController.text}" will start in 30 minutes.',
                              scheduledDateTime30min,meetingNameController.text
                            );

                            // Schedule the second notification (10 minutes before the meeting)
                            NotificationService.scheduleNotification(
                              DateTime.now().millisecondsSinceEpoch% 100000000,
                              'Meeting Reminder',
                              'Your meeting "${meetingNameController.text}" will start in 10 minutes.',
                              scheduledDateTime10min,meetingNameController.text
                            );
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
