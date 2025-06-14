import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Helpers/String.dart';
import 'package:mcd_attendance/Model/MeetingModel.dart';
import 'package:http/http.dart' as http;
import 'package:mcd_attendance/Model/TaskModel.dart';
import 'package:mcd_attendance/Screens/AddTaskForm.dart';
import 'package:mcd_attendance/Screens/NewAddTaskFormScreen.dart';

import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class NewAvailableTaskScreen extends StatefulWidget {
  @override
  _NewAvailableTaskScreenState createState() => _NewAvailableTaskScreenState();
}

class _NewAvailableTaskScreenState extends State<NewAvailableTaskScreen> {
  List<TaskDataModel> tasks = [];
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

        List<dynamic> taskJsonList = data['data'] ?? [];

        if (mounted) {
          setState(() {
            tasks = taskJsonList.map((json) => TaskDataModel.fromJson(json)).toList();
          });
        }
      } else {
        final errorMessage = "Failed to fetch tasks. Status: ${response.statusCode}";
        _showNullValueError("FetchTask Api: $errorMessage");
      }
    } catch (e) {
      final errorMessage = "Error while fetching tasks.\n${e.toString()}";
      _showNullValueError("FetchTask Api: $errorMessage");

      print("Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  Future<void> deleteTask(BuildContext context, String empBmid, String taskId) async {
    const String url = 'https://api.mcd.gov.in/app/request';
    const String token =
        'eyJhbGciOiJIUzI1NiJ9.e30.g2PzdcLXSunm0_ZW-5d9ptZSpeXZi0qsh_sTuTTojRs';

    var body = json.encode({
      "module": "task",
      "event": "delete",
      "params": {
        "emp_bmid": empBmid,
        "id": taskId,
      }
    });

    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 2) {
          // Show success dialog
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Center(
                    child: Text('Success', style: TextStyle(color: Colors.green))),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 50),
                    SizedBox(height: 10.h),
                    Text(data['msg'].toString()),
                  ],
                ),
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
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text("Okay", style: TextStyle(fontSize: 16.sp, color: Colors.white)),
                    ),
                  ),
                ],
              );
            },
          );
        } else {
          _showNullValueError("DeleteTask Api: ${data['msg']}");
        }
      } else {
        _showNullValueError("DeleteTask Api: Failed to delete task. Status: ${response.statusCode}");
      }
    } catch (e) {
      _showNullValueError("DeleteTask Api: Unexpected error occurred while deleting the task.\n${e.toString()}");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: (!isLoading)?true:false,
      appBar: const GlassAppBar(title: 'TASKS', isLayoutScreen: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_)=>NewAddTaskFormScreen(onFormSubmit: (context ) {
            fetchTask();
          },)));
        },
        backgroundColor: const Color(0xff111184), // You can change the color here
        child: const Icon(Icons.add,color: Colors.white,), // Icon to display in the FAB
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
                    return Dismissible(
                      key: Key(tasks[index].id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        // Show confirmation dialog before deleting
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
                                          style: TextStyle(fontSize: 16.sp, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                     SizedBox(width: 15.w),
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.grey),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context); // Close the dialog
                                          fetchTask();
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
                          ),
                        );
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20), // Red color for the swipe-to-delete background
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          _showTaskDetails(tasks[index]);
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          color: Colors.white60,
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
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
