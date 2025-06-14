import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Helpers/NotificationService.dart';
import 'package:mcd_attendance/Helpers/String.dart';
import 'package:mcd_attendance/Model/MeetingModel.dart';
import 'package:http/http.dart' as http;

import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class AvailableMeetingScreen extends StatefulWidget {
  final String payLoad;
  const AvailableMeetingScreen({super.key, required this.payLoad});
  @override
  _AvailableMeetingScreenState createState() => _AvailableMeetingScreenState();
}

class _AvailableMeetingScreenState extends State<AvailableMeetingScreen> {
  List<MeetingDataModel> meetings = [];
  bool isLoading = false;
  @override
  void initState() {
    super.initState();
   _checkInternetAndInitialize();
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
    fetchMeetings();
  }

  void _showMeetingDetails(MeetingDataModel meeting) {
    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // This allows the BottomSheet to resize based on content
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r), // Rounded corners
      ),
      builder: (context) {
        return Wrap(
          // Use Wrap to ensure the BottomSheet adjusts to content size
          children: [
            Padding(
              padding: EdgeInsets.all(16.0.sp),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meeting Details',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(thickness: 0.3,color: Colors.black,),
                    SizedBox(height: 16.h),
                    Text(
                      'Meeting Title: ${meeting.meetingTitle}',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Date: ${meeting.meetingDate}',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Time: ${meeting.meetingTime}',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Notes: ${meeting.meetingDescription ?? "No notes available"}',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
          ],
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

  Future<void> fetchMeetings() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    const String url = 'https://api.mcd.gov.in/app/request';
    const String token = 'eyJhbGciOiJIUzI1NiJ9.e30.rIxFKYxozQ7lXw7UNW_3CBS7YK-pfGkjkUmjIH0o8Ag';

    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    var request = http.Request('GET', Uri.parse(url));

    var body = json.encode({
      "module": "meeting",
      "event": "list",
      "params": {
        "emp_bmid": userBmid,
      }
    });

    request.body = body;
    request.headers.addAll(headers);

    try {
      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> data = json.decode(responseBody);

        List<dynamic> meetingsJson = data['data'] ?? [];

        if (mounted) {
          setState(() {
            meetings = meetingsJson
                .map((json) => MeetingDataModel.fromJson(json))
                .toList();
          });
        }

        MeetingDataModel matchingMeeting = meetings.firstWhere(
              (meeting) => meeting.meetingTitle == widget.payLoad,
          orElse: () => MeetingDataModel(
            id: '',
            meetingTitle: 'No Meeting',
            meetingDate: 'N/A',
            meetingTime: 'N/A',
            meetingDescription: '',
          ),
        );

        if (matchingMeeting.meetingTitle != 'No Meeting') {
          _showMeetingDetails(matchingMeeting);
        }

      } else {
        String errorMessage = "Failed to fetch data. Status: ${response.statusCode}";

        // ❗️ Show dialog for non-200 responses
        _showNullValueError("fetchMeetings Api: $errorMessage");
      }
    } catch (e) {
      final errorText = "Error: $e";

      // ❗️ Show dialog for exceptions
      _showNullValueError("fetchMeetings Api: $e");

      print(errorText);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  Future<void> deleteMeeting(BuildContext context, String empBmid, String meetingId) async {
    const String url = 'https://api.mcd.gov.in/app/request';

    // Prepare the data to be sent in the body
    var body = json.encode({
      "module": "meeting",
      "event": "delete",
      "params": {
        "emp_bmid": empBmid,
        "id": meetingId
      }
    });

    const String token = 'eyJhbGciOiJIUzI1NiJ9.e30.I6VSp1lpc6c62V8SeoJtTwUgds6gN07iMLWfokomGlc';

    // Set up the headers
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    };

    try {
      // Send DELETE request
      final response = await http.delete(Uri.parse(url), headers: headers, body: body);

      // Check if the status code is 200 (successful response)
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check if the response contains the correct msg field indicating success
        if (data['code'] == 2) {
          // Show success dialog
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Center(child: Text('Success',style: TextStyle(color: Colors.green),)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                       Icons.check_circle ,
                      color: Colors.green,
                      size: 50,
                    ),
                     SizedBox(height: 10.h),
                    Text(data['msg'].toString()),
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
        } else {
          // Show error dialog if the response msg is not 'Meeting deleted.'
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Center(child: Text('Failed',style: TextStyle(color: Colors.red),)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error ,
                      color: Colors.red,
                      size: 50,
                    ),
                     SizedBox(height: 10.h),
                    Text(data['msg'].toString()),
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
      } else {
        // Handle failed status code
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Center(child: Text('Failed',style: TextStyle(color: Colors.red),)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error ,
                    color: Colors.red,
                    size: 50,
                  ),
                   SizedBox(height: 10.h),
                  Text(response.body),
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
    } catch (e) {
      // Catch any errors like network issues
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Center(child: Text('Failed',style: TextStyle(color: Colors.red),)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error ,
                  color: Colors.red,
                  size: 50,
                ),
                 SizedBox(height: 10.h),
                Text(e.toString()),
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
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: 'AVAILABLE MEETINGS', isLayoutScreen: false),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : meetings.isEmpty
              ? const Center(child: Text('No meetings available'))
              : ListView.builder(
                  itemCount: meetings.length,
                  itemBuilder: (context, index) {
                    final meeting = meetings[index];
                    return GestureDetector(
                      onTap: (){
                        _showMeetingDetails(meeting);
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        child: ListTile(
                          title: Text(meeting.meetingTitle,style: const TextStyle(fontWeight: FontWeight.bold),),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date :${meeting.meetingDate}'),
                              Text('Time :${meeting.meetingTime}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              // Delete the meeting from the list
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  contentPadding: const EdgeInsets.all(20),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Animated Lottie Asset for Failure
                                      const Icon(Icons.warning,color: Colors.amber,size: 50,),
                                       SizedBox(height: 16.h),
                                      const Text(
                                        "Are you sure delete this meeting? ",
                                      ),
                                       SizedBox(height: 20.h),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
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
                                                deleteMeeting(context, userBmid, meetings[index].id,).then((_) {
                                                  fetchMeetings();
                                                  NotificationService.cancelNotifications(meetings[index].meetingTitle);
                                                });
                                              },
                                              child:  Text(
                                                "Yes",
                                                style: TextStyle(fontSize: 16.sp, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                           SizedBox(width: 15.w,),
                                          Expanded(
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Colors.grey),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              onPressed: () {
                                                Navigator.pop(context); // Close the dialog and navigate back

                                              },
                                              child:  Text(
                                                "Cancel",
                                                style: TextStyle(fontSize: 16.sp),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
