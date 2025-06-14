import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Helpers/String.dart';
import 'package:mcd_attendance/Model/MeetingModel.dart';
import 'package:http/http.dart' as http;
import 'package:mcd_attendance/Model/TaskModel.dart';

import 'Widgets/DialogBox.dart';

class AvailableTaskScreen extends StatefulWidget {
  @override
  _AvailableTaskScreenState createState() => _AvailableTaskScreenState();
}

class _AvailableTaskScreenState extends State<AvailableTaskScreen> {
  List<TaskDataModel> tasks = [];
  bool isLoading = false;
  @override
  void initState() {
    super.initState();
    fetchTask();
  }

  void _showTaskDetails(TaskDataModel tasks) {
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
                      'Task Details',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(
                      thickness: 0.3,
                      color: Colors.black,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Task Title: ${tasks.taskTitle}',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Task Deadline Date: ${tasks.taskDeadlineDate}',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Task Deadline Time: ${tasks.taskDeadlineTime}',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Completed task: ${tasks.taskInactive.toString() ?? "Not available"}',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Ongoing task: ${tasks.taskActive ?? "Not available"}',
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

  Future<void> fetchTask() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    const String url = 'https://api.mcd.gov.in/app/request';
    const String token =
        'eyJhbGciOiJIUzI1NiJ9.e30.g2PzdcLXSunm0_ZW-5d9ptZSpeXZi0qsh_sTuTTojRs';

    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    var request = http.Request('GET', Uri.parse(url));
    var body = json.encode({
      "module": "task",
      "event": "list",
      "params": {
        "emp_bmid": userBmid
      }
    });

    request.body = body;
    request.headers.addAll(headers);

    try {
      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> data = json.decode(responseBody);

        List<dynamic> tasksJson = data['data'] ?? [];

        if (mounted) {
          setState(() {
            tasks = tasksJson
                .map((json) => TaskDataModel.fromJson(json))
                .toList();
          });
        }
      } else {
        final errorText = "Failed to fetch data. Status: ${response.statusCode}";

        _showNullValueError("fetchTask: $errorText");
      }
    } catch (e) {
      final errorText = "Error: $e";

      _showNullValueError("fetchTask Exception: ${errorText.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  Future<void> deleteTask(
      BuildContext context, String empBmid, String taskId) async {
    const String url = 'https://api.mcd.gov.in/app/request';

    // Prepare the data to be sent in the body
    var body = json.encode({
      "module" : "task",
      "event" : "delete",
      "params" : {
        "emp_bmid": userBmid,
        "id": taskId
      }
    });

    const String token =
        'eyJhbGciOiJIUzI1NiJ9.e30.g2PzdcLXSunm0_ZW-5d9ptZSpeXZi0qsh_sTuTTojRs';

    // Set up the headers
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    };

    try {
      // Send DELETE request
      final response =
          await http.delete(Uri.parse(url), headers: headers, body: body);

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
                title: const Center(
                    child: Text(
                  'Success',
                  style: TextStyle(color: Colors.green),
                )),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 50,
                    ),
                     SizedBox(height: 10.h),
                    Text(data['msg'].toString()),
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
                title: const Center(
                    child: Text(
                  'Failed',
                  style: TextStyle(color: Colors.red),
                )),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error,
                      color: Colors.red,
                      size: 50,
                    ),
                     SizedBox(height: 10.h),
                    Text(data['msg'].toString()),
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
              title: const Center(
                  child: Text(
                'Failed',
                style: TextStyle(color: Colors.red),
              )),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 50,
                  ),
                   SizedBox(height: 10.h),
                  Text(response.body),
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
            title: const Center(
                child: Text(
              'Failed',
              style: TextStyle(color: Colors.red),
            )),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 50,
                ),
                 SizedBox(height: 10.h),
                Text(e.toString()),
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
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("AVAILABLE TASKS"),
        centerTitle: true,
      ),
      body: isLoading
          ?  Center(child: LottieBuilder.asset(
          'assets/animations/loading_animation.json',
          height: 50.h,
          width: 50.w))
          : tasks.isEmpty
              ? const Center(child: Text('No task available'))
              : ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        _showTaskDetails(tasks[index]);
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        child: ListTile(
                          title: Text(
                            tasks[index].taskTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date :${tasks[index].taskDeadlineDate}'),
                              Text('Time :${tasks[index].taskDeadlineTime}'),
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
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.all(20),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Animated Lottie Asset for Failure
                                            const Icon(
                                              Icons.warning,
                                              color: Colors.amber,
                                              size: 50,
                                            ),
                                             SizedBox(height: 16.h),
                                            const Text(
                                              "Are you sure delete this task? ",
                                            ),
                                             SizedBox(height: 20.h),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                              0xff111184),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.pop(
                                                          context); // Close the dialog
                                                      deleteTask(
                                                        context,
                                                        userBmid,
                                                        tasks[index].id,
                                                      ).then((_) {
                                                        fetchTask();
                                                      });
                                                    },
                                                    child:  Text(
                                                      "Yes",
                                                      style: TextStyle(
                                                          fontSize: 16.sp,
                                                          color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                                 SizedBox(
                                                  width: 15.w,
                                                ),
                                                Expanded(
                                                  child: OutlinedButton(
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      side: const BorderSide(
                                                          color: Colors.grey),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.pop(
                                                          context); // Close the dialog and navigate back
                                                    },
                                                    child:  Text(
                                                      "Cancel",
                                                      style: TextStyle(
                                                          fontSize: 16.sp),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ));
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
