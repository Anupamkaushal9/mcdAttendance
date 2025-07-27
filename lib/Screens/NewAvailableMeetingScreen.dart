import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Helpers/Constant.dart';
import 'package:mcd_attendance/Helpers/NotificationService.dart';
import 'package:mcd_attendance/Helpers/String.dart';
import 'package:mcd_attendance/Model/MeetingModel.dart';
import 'package:http/http.dart' as http;
import 'package:mcd_attendance/Screens/AddMeetingForm.dart';
import 'package:table_calendar/table_calendar.dart';

import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class NewAvailableMeetingScreen extends StatefulWidget {
  final String payLoad;
  const NewAvailableMeetingScreen({super.key, required this.payLoad});
  @override
  _NewAvailableMeetingScreenState createState() =>
      _NewAvailableMeetingScreenState();
}

class _NewAvailableMeetingScreenState extends State<NewAvailableMeetingScreen> {
  List<MeetingDataModel> meetings = [];
  bool isLoading = false;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final ValueNotifier<List<MeetingDataModel>> _selectedMeetings =
      ValueNotifier([]);
  final ValueNotifier<Map<DateTime, List<MeetingDataModel>>> _meetingsMap =
      ValueNotifier({});

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
    _selectedDay = _focusedDay;
    fetchMeetings();
  }

  @override
  void dispose() {
    _selectedMeetings.dispose();
    _meetingsMap.dispose();
    super.dispose();
  }

  void _showMeetingDetails(MeetingDataModel meeting) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      builder: (context) {
        return Wrap(
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
                    const Divider(thickness: 0.3, color: Colors.black),
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

  List<MeetingDataModel> _getMeetingsForDay(DateTime day) {
    final formattedDay = DateTime(day.year, day.month, day.day);
    return _meetingsMap.value[formattedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedMeetings.value = _getMeetingsForDay(selectedDay);
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

  Future<void> fetchMeetings() async {
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
      "module": "meeting",
      "event": "list",
      "params": {
        "emp_bmid": userBmid,
        "date": "", // Fetch all meetings
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
        List<MeetingDataModel> allMeetings = meetingsJson
            .map((json) => MeetingDataModel.fromJson(json))
            .toList();

        Map<DateTime, List<MeetingDataModel>> meetingsMap = {};
        for (var meeting in allMeetings) {
          try {
            DateTime meetingDate = DateFormat('yyyy-MM-dd')
                .parse(meeting.meetingDate.split(' ')[0]);
            DateTime dateKey =
            DateTime(meetingDate.year, meetingDate.month, meetingDate.day);

            meetingsMap.putIfAbsent(dateKey, () => []);
            meetingsMap[dateKey]!.add(meeting);
          } catch (e) {
            debugPrint('Error parsing date for meeting: ${meeting.meetingDate}');
          }
        }

        _meetingsMap.value = meetingsMap;
        _selectedMeetings.value = _getMeetingsForDay(_selectedDay!);

        if (widget.payLoad.isNotEmpty) {
          MeetingDataModel? matchingMeeting = allMeetings.firstWhere(
                (meeting) => meeting.meetingTitle == widget.payLoad,
            orElse: () => MeetingDataModel(
                id: '',
                meetingTitle: 'No Meeting',
                meetingDate: 'N/A',
                meetingTime: 'N/A',
                meetingDescription: ''),
          );

          if (matchingMeeting.meetingTitle != 'No Meeting') {
            _showMeetingDetails(matchingMeeting);
          }
        }
      } else {
        String errorMsg = "Failed to fetch meetings. Status: ${response.statusCode}";
        _showNullValueError("FetchMeeting Api: $errorMsg");
      }
    } catch (e) {
      String errorMsg = "An unexpected error occurred while fetching meetings.";
      _showNullValueError("FetchMeeting Api: $errorMsg");
      debugPrint("Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
    }

  Future<void> deleteMeeting(BuildContext context, String empBmid, String meetingId) async {
    const String url = newBaseUrl;
    const String token =
        'eyJhbGciOiJIUzI1NiJ9.e30.I6VSp1lpc6c62V8SeoJtTwUgds6gN07iMLWfokomGlc';

    var body = json.encode({
      "module": "meeting",
      "event": "delete",
      "params": {
        "emp_bmid": empBmid,
        "id": meetingId,
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
                  child: Text('Success', style: TextStyle(color: Colors.green)),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 50),
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
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text("Okay", style: TextStyle(fontSize: 16.sp, color: Colors.white)),
                    ),
                  ),
                ],
              );
            },
          );
        } else {
          // API responded but with an error
          _showNullValueError("DeleteMeeting Api: ${data['msg']}");
        }
      } else {
        final errorText = "Failed to delete meeting. Status: ${response.statusCode}";
        _showNullValueError("DeleteMeeting Api: $errorText");
      }
    } catch (e) {
      _showNullValueError("DeleteMeeting Api: Unexpected error occurred while deleting the meeting.\n${e.toString()}");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: false,
      appBar: const GlassAppBar(title: 'MEETINGS', isLayoutScreen: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AddMeetingFormScreen(
                    onFormSubmit: (context) {
                      setState(() {
                        fetchMeetings();
                      });

                    },
                  )));
        },
        backgroundColor: const Color(0xff111184), // You can change the color here
        child: const Icon(Icons.add,color: Colors.white,), // Icon to display in the FAB
      ),
      body: Padding(
        padding:  const EdgeInsets.only(left: 8.0,right: 8.0,bottom: 8.0,top: 0),
        child: Column(
          children: [
            ValueListenableBuilder<Map<DateTime, List<MeetingDataModel>>>(
              valueListenable: _meetingsMap,
              builder: (context, meetingsMap, _) {
                return TableCalendar<MeetingDataModel>(
                  firstDay: DateTime(2000),
                  lastDay: DateTime(2101),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  eventLoader: _getMeetingsForDay,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  headerStyle:  HeaderStyle(
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
                    selectedDecoration: const BoxDecoration(
                      color: Color(0xff111184),
                      shape: BoxShape.circle,
                    ),
                    defaultDecoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xff111184),
                        width: 0.5,
                      ),
                    ),
                    weekendDecoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xff111184),
                        width: 0.5,
                      ),
                    ),
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
                              style:  TextStyle(
                                fontSize: 10.0.sp,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }
                      return null;
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
                    child: ValueListenableBuilder<List<MeetingDataModel>>(
                      valueListenable: _selectedMeetings,
                      builder: (context, meetings, _) {
                        if (meetings.isEmpty) {
                          return const Center(
                              child: Text('No meetings available for this date'));
                        }

                        return ListView.builder(
                          itemCount: meetings.length,
                          itemBuilder: (context, index) {
                            final meeting = meetings[index];
                            return Dismissible(
                              key: Key(meeting.id.toString()), // Unique key for each item
                              direction: DismissDirection.endToStart, // Swipe from right to left
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20), // Background color when swiped
                                child: const Icon(Icons.delete, color: Colors.white, size: 40),
                              ),
                              onDismissed: (direction) {
                                // When the item is dismissed, trigger the delete action
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
                                      const Icon(Icons.warning,
                                          color: Colors.amber, size: 50),
                                       SizedBox(height: 16.h),
                                      const Text("Are you sure you want to delete this meeting?"),
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
                                                Navigator.pop(context);
                                                deleteMeeting(context, userBmid, meeting.id)
                                                    .then((_) {
                                                  fetchMeetings();
                                                  NotificationService.cancelNotifications(meeting.meetingTitle);
                                                });
                                              },
                                              child:  Text("Yes",
                                                  style: TextStyle(fontSize: 16.sp, color: Colors.white)),
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
                                                fetchMeetings();
                                                Navigator.pop(context);

                                              } ,
                                              child:  Text("Cancel", style: TextStyle(fontSize: 16.sp)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ));
                              },
                              child: GestureDetector(
                                onTap: () => _showMeetingDetails(meeting),
                                child: Card(
                                  color: Colors.white60,
                                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                  child: ListTile(
                                    title: Text(meeting.meetingTitle,
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Date: ${meeting.meetingDate}'),
                                        Text('Time: ${meeting.meetingTime}'),
                                      ],
                                    ),
                                  ),
                                ),
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
}
