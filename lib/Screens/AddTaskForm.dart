import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:mcd_attendance/Helpers/Constant.dart';
import 'package:mcd_attendance/Model/MeetingModel.dart';
import 'package:mcd_attendance/Screens/DeviceRegistrationScreen.dart';
import 'package:mcd_attendance/Screens/LayoutScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/AppBtn.dart';
import '../Helpers/DbHelper.dart';
import '../Helpers/Session.dart';
import '../Helpers/String.dart';
import '../Model/Employee.dart';
import 'LoginScreen.dart';

class AddTaskFormScreen extends StatefulWidget {
  const AddTaskFormScreen({super.key});

  @override
  State<AddTaskFormScreen> createState() => _AddTaskFormScreenState();
}

class _AddTaskFormScreenState extends State<AddTaskFormScreen> {
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  bool isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers for the form fields
  final taskNameController = TextEditingController();
  final taskDateController = TextEditingController();
  final taskTimeController = TextEditingController();

  // List to hold checklist items
  List<ChecklistItem> checklistItems = [
    ChecklistItem(text: '', isCompleted: false),
  ];

  @override
  void dispose() {
    super.dispose();
    taskNameController.dispose();
    taskDateController.dispose();
    taskTimeController.dispose();
    // No need to dispose checklist item controllers as they're managed in the ChecklistItem class
  }

  Future<void> addTask(BuildContext context) async {
    setState(() {
      isLoading = true;
    });

    // Separate checklist items into active and inactive
    List<String> taskActive = [];
    List<String> taskInactive = [];

    for (var item in checklistItems) {
      if (item.text.isNotEmpty) {
        if (item.isCompleted) {
          taskInactive.add(item.text);
        } else {
          taskActive.add(item.text);
        }
      }
    }

    // API Request
    const url = 'https://api.mcd.gov.in/app/request';
    const token = 'eyJhbGciOiJIUzI1NiJ9.e30.g2PzdcLXSunm0_ZW-5d9ptZSpeXZi0qsh_sTuTTojRs';

    final requestBody = {
      "module": "task",
      "event": "add",
      "params": {
        "task_title": taskNameController.text,
        "task_deadline_date": taskDateController.text,
        "task_deadline_time": taskTimeController.text,
        "task_active": taskActive,
        "task_inactive": taskInactive,
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
        Navigator.of(context).pop();
        _showDialog(context, 'Task Added!', 'Your task has been created.', Colors.green);
      } else {
        _showDialog(context, 'Failed to Add Task', response.body, Colors.red);
      }
    } catch (e) {
      _showDialog(context, 'Error', e.toString(), Colors.red);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showDialog(
      BuildContext context, String title, String message, Color color) {
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
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff111184),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:  Text(
                    "Okay",
                    style: TextStyle(fontSize: 16.sp, color: Colors.white),
                  ),
                )),
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
    );

    if (picked != null && picked != DateTime.now()) {
      setState(() {
        taskDateController.text = '${picked.toLocal()}'.split(' ')[0];
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        taskTimeController.text =
            "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  // Add a new checklist item
  void _addChecklistItem() {
    setState(() {
      checklistItems.add(ChecklistItem(text: '', isCompleted: false));
    });
  }

  // Remove a checklist item
  void _removeChecklistItem(int index) {
    setState(() {
      checklistItems.removeAt(index);
      // Ensure there's always at least one item
      if (checklistItems.isEmpty) {
        checklistItems.add(ChecklistItem(text: '', isCompleted: false));
      }
    });
  }

  // Update a checklist item
  void _updateChecklistItem(int index, String newText) {
    setState(() {
      checklistItems[index].text = newText;
    });
  }

  // Toggle checkbox state
  void _toggleCheckbox(int index, bool? newValue) {
    setState(() {
      checklistItems[index].isCompleted = newValue ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("MCD Smart"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add Task",
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20.h),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Task Title Field
                  TextFormField(
                    controller: taskNameController,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        gapPadding: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the task title';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Task Deadline Field
                  TextFormField(
                    controller: taskDateController,
                    decoration: InputDecoration(
                      labelText: 'Task Deadline Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 14.h, horizontal: 16.w),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the task deadline date';
                      }
                      return null;
                    },
                    onTap: () => _selectDate(context),
                  ),
                  SizedBox(height: 16.h),

                  TextFormField(
                    controller: taskTimeController,
                    decoration: InputDecoration(
                      labelText: 'Task deadline time',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 14.h, horizontal: 16.w),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the deadline time';
                      }
                      return null;
                    },
                    onTap: (){
                      _selectTime(context);
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Checklist Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checklist Items',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Column(
                          children: [
                            ...checklistItems.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;

                              return ChecklistItemWidget(
                                item: item,
                                onChanged: (newText) =>
                                    _updateChecklistItem(index, newText),
                                onCheckboxChanged: (newValue) =>
                                    _toggleCheckbox(index, newValue),
                                onSubmitted: (_) => _addChecklistItem(),
                                onDeleted: () => _removeChecklistItem(index),
                                isLast: index == checklistItems.length - 1,
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Add Button
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final hasItems = checklistItems.any((item) => item.text.isNotEmpty);
                          if (_formKey.currentState!.validate()) {
                            if (hasItems) {
                              addTask(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please add at least one task item'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 15.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: const Color(0xff111184),
                      ),
                      child: isLoading
                          ?  Center(
                              child: SizedBox(
                                height: 20.h,
                                width: 20.w,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Text('Add Task',
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

// Model for checklist items

class ChecklistItem {
  String text;
  bool isCompleted;
  final TextEditingController controller = TextEditingController();

  ChecklistItem({required this.text, required this.isCompleted}) {
    controller.text = text;
  }
}

// Widget for individual checklist items
class ChecklistItemWidget extends StatelessWidget {
  final ChecklistItem item;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool?> onCheckboxChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onDeleted;
  final bool isLast;

  const ChecklistItemWidget({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onCheckboxChanged,
    required this.onSubmitted,
    required this.onDeleted,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align items at the top
        children: [
          // Checkbox
          Checkbox(
            value: item.isCompleted,
            onChanged: onCheckboxChanged,
          ),

          // Expanded text field
          Expanded(
            child: TextField(
              controller: item.controller,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Describe your task here',
              ),
              maxLines: null, // Allows unlimited lines
              keyboardType: TextInputType.multiline, // Shows multiline keyboard
              onChanged: onChanged,
              onSubmitted: isLast ? onSubmitted : null, // Only submit on last item
              textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
            ),
          ),

          // Delete button (only show if there's text or if there are multiple items)
          if (item.text.isNotEmpty || !isLast)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDeleted,
            ),
        ],
      ),
    );
  }
}
