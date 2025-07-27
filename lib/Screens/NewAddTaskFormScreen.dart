import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mcd_attendance/Helpers/Constant.dart';

import '../Helpers/String.dart';
import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class NewAddTaskFormScreen extends StatefulWidget {
  final Function(BuildContext) onFormSubmit;
  const NewAddTaskFormScreen({super.key, required this.onFormSubmit});

  @override
  State<NewAddTaskFormScreen> createState() => _NewAddTaskFormScreenState();
}

class _NewAddTaskFormScreenState extends State<NewAddTaskFormScreen> {
  bool isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers for the form fields
  final taskNameController = TextEditingController();
  final taskDateController = TextEditingController();
  final taskTimeController = TextEditingController();

  // AnimatedList keys
  final GlobalKey<AnimatedListState> _ongoingListKey = GlobalKey<AnimatedListState>();
  final GlobalKey<AnimatedListState> _completedListKey = GlobalKey<AnimatedListState>();

  // Lists for ongoing and completed checklist items
  List<ChecklistItem> ongoingItems = [
    ChecklistItem(text: '', isCompleted: false),
  ];

  List<ChecklistItem> completedItems = [];

  @override
  void dispose() {
    taskNameController.dispose();
    taskDateController.dispose();
    taskTimeController.dispose();
    for (var item in ongoingItems) {
      item.dispose();
    }
    for (var item in completedItems) {
      item.dispose();
    }
    super.dispose();
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
        taskDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
      // No longer automatically opens time picker
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    if (taskDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date first')));
      return;
    }

    final selectedDate = DateFormat('yyyy-MM-dd').parse(taskDateController.text);
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
        taskTimeController.text = formattedTime;
      });
    }
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

  Future<void> addTask(BuildContext context) async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    // Separate ongoing and completed tasks
    List<String> taskActive = [];
    List<String> taskInactive = [];

    for (var item in ongoingItems) {
      if (item.text.isNotEmpty) {
        taskActive.add(item.text);
      }
    }

    for (var item in completedItems) {
      if (item.text.isNotEmpty) {
        taskInactive.add(item.text);
      }
    }

    const url = newBaseUrl;
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
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        widget.onFormSubmit(context);
        if (mounted) Navigator.of(context).pop();

        _showDialog(
          context,
          'Task Added!',
          'Your task has been created.',
          Colors.green,
        );
      } else {
        final errorMessage = 'Failed to add task. Status: ${response.statusCode}';
        _showNullValueError("AddTask Api:$errorMessage");

        _showDialog(
          context,
          'Failed to Add Task',
          response.body,
          Colors.red,
        );
      }
    } catch (e) {
      final exceptionMessage = 'Error occurred: ${e.toString()}';
      _showNullValueError("AddTask Api: $exceptionMessage");

      _showDialog(
        context,
        'Error',
        exceptionMessage,
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  void _updateChecklistItem(int index, String newText, bool isCompleted) {
    setState(() {
      if (isCompleted) {
        completedItems[index].text = newText;
      } else {
        ongoingItems[index].text = newText;
      }
    });
  }

  void _toggleCheckbox(int index, bool isCompletedList, bool? newValue) {
    if (isCompletedList) {
      // Moving from completed to ongoing
      if (newValue != null && !newValue) {
        final item = completedItems[index];
        _completedListKey.currentState?.removeItem(
          index,
              (context, animation) => _buildRemovedItem(item, animation),
          duration: const Duration(milliseconds: 300),
        );

        setState(() {
          item.isCompleted = false;
          completedItems.removeAt(index);
        });

        _ongoingListKey.currentState?.insertItem(
          ongoingItems.length,
          duration: const Duration(milliseconds: 300),
        );

        setState(() {
          ongoingItems.add(item);
        });
      }
    } else {
      // Moving from ongoing to completed
      var item = ongoingItems[index];
      if (newValue != null && newValue && item.text.trim().isNotEmpty) {
        _ongoingListKey.currentState?.removeItem(
          index,
              (context, animation) => _buildRemovedItem(item, animation),
          duration: const Duration(milliseconds: 300),
        );

        setState(() {
          item.isCompleted = true;
          ongoingItems.removeAt(index);
        });

        _completedListKey.currentState?.insertItem(
          completedItems.length,
          duration: const Duration(milliseconds: 300),
        );

        setState(() {
          completedItems.add(item);
        });
      } else {
        setState(() {
          item.isCompleted = false;
        });
      }
    }

    // Ensure there's always at least one empty ongoing item
    if (ongoingItems.isEmpty) {
      setState(() {
        ongoingItems.add(ChecklistItem(text: '', isCompleted: false));
      });
      _ongoingListKey.currentState?.insertItem(0);
    }
  }

  Widget _buildRemovedItem(ChecklistItem item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: ChecklistItemWidget(
        item: item,
        onChanged: (newText) {},
        onCheckboxChanged: (newValue) {},
        onDeleted: () {},
        isLast: false,
      ),
    );
  }

  void _addChecklistItem() {
    final newIndex = ongoingItems.length;
    final newItem = ChecklistItem(text: '', isCompleted: false);
    setState(() {
      ongoingItems.add(newItem);
    });
    _ongoingListKey.currentState?.insertItem(newIndex);

    // Focus the new item after it's added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      newItem.focusNode.requestFocus();
    });
  }

  void _removeChecklistItem(int index, bool isCompleted) {
    if (isCompleted) {
      if (index >= 0 && index < completedItems.length) {
        final removedItem = completedItems[index];
        _completedListKey.currentState?.removeItem(
          index,
              (context, animation) => _buildRemovedItem(removedItem, animation),
          duration: const Duration(milliseconds: 300),
        );

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              completedItems.removeAt(index);
            });
          }
        });
      }
    } else {
      if (index >= 0 && index < ongoingItems.length) {
        final removedItem = ongoingItems[index];
        _ongoingListKey.currentState?.removeItem(
          index,
              (context, animation) => _buildRemovedItem(removedItem, animation),
          duration: const Duration(milliseconds: 300),
        );

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              ongoingItems.removeAt(index);

              if (ongoingItems.isEmpty) {
                ongoingItems.add(ChecklistItem(text: '', isCompleted: false));
                _ongoingListKey.currentState?.insertItem(0);
              }
            });
          }
        });
      }
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
                  // Task Title Field
                  TextFormField(
                    controller: taskNameController,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the task title';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20.h),

                  // Task Deadline Field
                  Row(
                    children: [
                      // Deadline Date
                      Expanded(
                        child: TextFormField(
                          controller: taskDateController,
                          decoration: InputDecoration(
                            labelText: 'Deadline Date',
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
                          controller: taskTimeController,
                          decoration: InputDecoration(
                            labelText: 'Deadline Time',
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

                  // Ongoing Tasks Section
                  Container(
                    padding:
                    EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Ongoing Tasks',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        AnimatedList(
                          key: _ongoingListKey,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          initialItemCount: ongoingItems.length,
                          itemBuilder: (context, index, animation) {
                            return KeyedSubtree(
                              key: ValueKey(ongoingItems[index].hashCode),
                              child: SizeTransition(
                                sizeFactor: animation,
                                child: ChecklistItemWidget(
                                  item: ongoingItems[index],
                                  onChanged: (newText) =>
                                      _updateChecklistItem(index, newText, false),
                                  onCheckboxChanged: (newValue) =>
                                      _toggleCheckbox(index, false, newValue),
                                  onDeleted: () => _removeChecklistItem(index, false),
                                  isLast: index == ongoingItems.length - 1,
                                  onAddNewItem: _addChecklistItem,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Completed Tasks Section
                  Visibility(
                    visible: completedItems.isNotEmpty,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          vertical: 10.h, horizontal: 10.w),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Completed Tasks',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          AnimatedList(
                            key: _completedListKey,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            initialItemCount: completedItems.length,
                            itemBuilder: (context, index, animation) {
                              return KeyedSubtree(
                                key: ValueKey(completedItems[index].hashCode),
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  child: ChecklistItemWidget(
                                    item: completedItems[index],
                                    onChanged: (newText) =>
                                        _updateChecklistItem(index, newText, true),
                                    onCheckboxChanged: (newValue) =>
                                        _toggleCheckbox(index, true, newValue),
                                    onDeleted: () =>
                                        _removeChecklistItem(index, true),
                                    isLast: index == completedItems.length - 1,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Add Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final hasItems =
                          ongoingItems.any((item) => item.text.isNotEmpty);
                          if (hasItems) {
                            addTask(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                Text('Please add at least one task item'),
                                duration: Duration(seconds: 2),
                              ),
                            );
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

class ChecklistItem {
  String text;
  bool isCompleted;
  bool hasFocus;
  final TextEditingController controller;
  final FocusNode focusNode;

  ChecklistItem({required this.text, required this.isCompleted})
      : controller = TextEditingController(text: text),
        focusNode = FocusNode(),
        hasFocus = false;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class ChecklistItemWidget extends StatefulWidget {
  final ChecklistItem item;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool?> onCheckboxChanged;
  final VoidCallback onDeleted;
  final bool isLast;
  final VoidCallback? onAddNewItem;
  final FocusNode? nextFocusNode;

  const ChecklistItemWidget({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onCheckboxChanged,
    required this.onDeleted,
    required this.isLast,
    this.onAddNewItem,
    this.nextFocusNode,
  });

  @override
  State<ChecklistItemWidget> createState() => _ChecklistItemWidgetState();
}

class _ChecklistItemWidgetState extends State<ChecklistItemWidget> {
  @override
  void initState() {
    super.initState();
    widget.item.focusNode.addListener(_handleFocusChange);
    if (widget.item.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.item.focusNode.requestFocus();
      });
    }
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
  }

  @override
  void dispose() {
    widget.item.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() => widget.item.hasFocus = widget.item.focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.item.text.isNotEmpty || widget.item.hasFocus)
                Padding(
                  padding: EdgeInsets.only(top: 2.h, right: 8.w),
                  child: Transform.scale(
                    scale: 1.2,
                    child: Checkbox(
                      value: widget.item.isCompleted,
                      onChanged: widget.onCheckboxChanged,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      side: BorderSide(
                        color: Colors.grey.shade400,
                        width: 1.5,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(width: 10.w),

              Expanded(
                child: TextField(
                  controller: widget.item.controller,
                  focusNode: widget.item.focusNode,
                  onTap: () => widget.item.focusNode.requestFocus(),
                  style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade800),
                  decoration: InputDecoration(
                    hintText: 'Describe your task here...',
                    hintStyle: TextStyle(fontSize: 16.sp, color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                    isDense: true,
                  ),
                  maxLines: null,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  onChanged: widget.onChanged,
                  onSubmitted: (value) {
                    if (widget.isLast) {
                      widget.onAddNewItem?.call();
                    } else if (widget.nextFocusNode != null) {
                      widget.nextFocusNode?.requestFocus();
                    }
                  },
                  textInputAction: widget.isLast ? TextInputAction.done : TextInputAction.next,
                ),
              ),

              if (widget.item.text.isNotEmpty || !widget.isLast)
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 24.sp, color: Colors.grey.shade500),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onDeleted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}