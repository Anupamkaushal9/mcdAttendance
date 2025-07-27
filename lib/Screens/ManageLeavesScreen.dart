import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Helpers/Constant.dart';
import 'package:mcd_attendance/Helpers/String.dart';
import 'package:mcd_attendance/Model/ManageLeavesModel.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class ManageLeavesScreen extends StatefulWidget {
  const ManageLeavesScreen({super.key});

  @override
  _ManageLeaveScreenState createState() => _ManageLeaveScreenState();
}

class _ManageLeaveScreenState extends State<ManageLeavesScreen> {
  List<LeavesModel> leaves = [];
  bool isLoading = false;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final ValueNotifier<List<LeavesModel>> _selectedLeaves = ValueNotifier([]);
  final ValueNotifier<Map<DateTime, List<LeavesModel>>> _leavesMap =
  ValueNotifier({});
  final Map<String, Color> _colorMap = {
    'yellow': Colors.yellow,
    'red': Colors.red,
    'green': Colors.green,
    'blue': Colors.blue,
    // Add more colors as needed
  };

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
              (Platform.isAndroid)
                  ? FlutterExitApp.exitApp()
                  : FlutterExitApp.exitApp(iosForceExit: true);
            },
          );
        },
      );
      return;
    }
    _selectedDay = _focusedDay;
    fetchLeaves();
  }

  @override
  void dispose() {
    _selectedLeaves.dispose();
    _leavesMap.dispose();
    super.dispose();
  }

  void _showLeaveDetails(LeavesModel leave) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,  // Still important for full height
      enableDrag: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // Keyboard space
            left: 16.w,
            right: 16.w,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9, // Use most of screen
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 8.h, bottom: 16.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),

              // Content
              Flexible(  // Allows content to fit available space
                child: ListView(
                  shrinkWrap: true,  // Important for proper sizing
                  physics: const NeverScrollableScrollPhysics(), // Disables scrolling
                  children: [
                    Text(
                      'Leave Details',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    const Divider(thickness: 0.5),
                    SizedBox(height: 5.h),

                    _buildDetailRow('Date', leave.date),
                    SizedBox(height: 16.h),

                    _buildDetailRow('Type', leave.type),
                    SizedBox(height: 16.h),

                    if (leave.subType != null) ...[
                      _buildDetailRow('Sub Type', leave.subType!),
                      SizedBox(height: 16.h),
                    ],

                    if (leave.remark != null) ...[
                      _buildDetailRow('Remarks', leave.remark!),
                      SizedBox(height: 16.h),
                    ],

                    _buildDetailRow(
                      'Marked By',
                      leave.markedBy.isNotEmpty ? leave.markedBy : "Not available",
                      isImportant: false,
                    ),

                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isImportant = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: isImportant ? FontWeight.bold : FontWeight.normal,
            color: isImportant ? Colors.blue : Colors.black,
          ),
        ),
      ],
    );
  }

  List<LeavesModel> _getLeavesForDay(DateTime day) {
    final formattedDay = DateTime(day.year, day.month, day.day);
    return _leavesMap.value[formattedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedLeaves.value = _getLeavesForDay(selectedDay);
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

  Future<void> fetchLeaves() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    const String url = newBaseUrl;
    const String token =
        'eyJhbGciOiJIUzI1NiJ9.e30.rIxFKYxozQ7lXw7UNW_3CBS7YK-pfGkjkUmjIH0o8Ag';

    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    var request = http.Request('GET', Uri.parse(url));
    var body = json.encode({
      "module": "leave",
      "event": "list",
      "params": {"emp_bmid": userBmid, "year": DateTime.now().year}
    });

    request.body = body;
    request.headers.addAll(headers);

    try {
      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> data = json.decode(responseBody);

        List<dynamic> leavesJson = data['data'] ?? [];
        List<LeavesModel> allLeaves =
        leavesJson.map((json) => LeavesModel.fromJson(json)).toList();

        Map<DateTime, List<LeavesModel>> leavesMap = {};
        for (var leave in allLeaves) {
          try {
            DateTime leaveDate = DateFormat('yyyy-MM-dd').parse(leave.date);
            DateTime dateKey =
            DateTime(leaveDate.year, leaveDate.month, leaveDate.day);

            leavesMap.putIfAbsent(dateKey, () => []);
            leavesMap[dateKey]!.add(leave);
          } catch (e) {
            debugPrint('Error parsing date for leave: ${leave.date}');
          }
        }

        _leavesMap.value = leavesMap;
        _selectedLeaves.value = _getLeavesForDay(_selectedDay!);
      } else {
        String errorMsg =
            "Failed to fetch leaves. Status: ${response.statusCode}";
        _showNullValueError("FetchLeaves Api: $errorMsg");
      }
    } catch (e) {
      String errorMsg = "An unexpected error occurred while fetching leaves.";
      _showNullValueError("FetchLeaves Api: $errorMsg");
      debugPrint("Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: false,
      appBar: const GlassAppBar(title: 'MANAGE LEAVES', isLayoutScreen: false),
      body: Padding(
        padding:
        const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0, top: 0),
        child: Column(
          children: [
            ValueListenableBuilder<Map<DateTime, List<LeavesModel>>>(
              valueListenable: _leavesMap,
              builder: (context, leavesMap, _) {
                return TableCalendar<LeavesModel>(
                  firstDay: DateTime(2000),
                  lastDay: DateTime(2101),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  eventLoader: _getLeavesForDay,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    leftChevronVisible: true,
                    rightChevronVisible: true,
                    titleTextStyle: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xff111184),
                    ),
                    headerMargin: const EdgeInsets.symmetric(vertical: 10),
                    headerPadding: const EdgeInsets.symmetric(horizontal: 0),
                  ),
                  calendarStyle: CalendarStyle(
                    // These are defaults that can be overridden by the builders
                    defaultTextStyle: TextStyle(fontSize: 14.sp),
                    todayTextStyle: TextStyle(fontSize: 14.sp),
                    selectedTextStyle: TextStyle(fontSize: 14.sp),
                    outsideTextStyle: TextStyle(fontSize: 14.sp),
                  ),
                  onDaySelected: _onDaySelected,
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    }
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        return Positioned(
                          right: 1,
                          top: 1,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xff50C878),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${events.length}',
                              style: TextStyle(
                                fontSize: 10.0.sp,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                    defaultBuilder: (context, date, _) {
                      return _buildDayCell(context, date);
                    },
                    todayBuilder: (context, date, _) {
                      return _buildDayCell(context, date);
                    },
                    selectedBuilder: (context, date, _) {
                      return _buildDayCell(context, date, isSelected: true);
                    },
                    outsideBuilder: (context, date, _) {
                      return _buildDayCell(context, date, isOutside: true);
                    },
                  ),
                );
              },
            ),
            SizedBox(height: 8.0.h),
            isLoading
                ? Expanded(
                child: Center(
                    child: LottieBuilder.asset(
                        'assets/animations/loading_animation.json',
                        height: 50.h,
                        width: 50.w)))
                : Expanded(
              child: ValueListenableBuilder<List<LeavesModel>>(
                valueListenable: _selectedLeaves,
                builder: (context, leaves, _) {
                  if (leaves.isEmpty) {
                    return const Center(
                        child: Text('No leaves available for this date'));
                  }

                  return ListView.builder(
                    itemCount: leaves.length,
                    itemBuilder: (context, index) {
                      final leave = leaves[index];
                      return Card(
                        color: Colors.white60,
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 5),
                        child: ListTile(
                          onTap: () => _showLeaveDetails(leave),
                          leading: Container(
                            width: 10.w,
                            // height: 40.h,
                            decoration: BoxDecoration(
                              color:
                              _colorMap[leave.color] ?? Colors.grey,
                              borderRadius: BorderRadius.circular(0),
                            ),
                          ),
                          title: Text(leave.type,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date: ${leave.date}'),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 16),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method
  Widget _buildDayCell(BuildContext context, DateTime date,
      {bool isSelected = false, bool isOutside = false}) {
    final leaves = _getLeavesForDay(date);
    final textColor = isOutside ? Colors.grey : Colors.black;

    if (leaves.isNotEmpty) {
      final leave = leaves.first;
      final color = _colorMap[leave.color] ?? Colors.transparent;

      return Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff111184) : color.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xff111184) : color,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: isSelected ? Colors.white : textColor,
              fontSize: 14.sp,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xff111184) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? const Color(0xff111184) : const Color(0xff111184),
          width: isSelected ? 2 : 0.5,
        ),
      ),
      child: Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: isSelected ? Colors.white : textColor,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }
}
