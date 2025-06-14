import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:mcd_attendance/Model/EmployeeHistoryModel.dart';

class EmpHistoryWidget extends StatefulWidget {
  final EmpHistoryData empHistoryData;
  final int index;

  const EmpHistoryWidget({
    super.key,
    required this.empHistoryData,
    required this.index,
  });

  @override
  State<EmpHistoryWidget> createState() => _EmpHistoryWidgetState();
}

class _EmpHistoryWidgetState extends State<EmpHistoryWidget> {
  String dateValue = '';
  String dayValue = '';
  String clockInValue = '';
  String clockOutValue = '';
  String workingHrValue = '';

  @override
  void initState() {
    super.initState();
    getColumnValues();
  }

  void getColumnValues() {
    String inTimeString = widget.empHistoryData.inTime!;
    DateTime inTime = DateTime.parse(inTimeString);

    DateFormat dateFormat = DateFormat("dd");
    dateValue = dateFormat.format(inTime);

    DateFormat dayFormat = DateFormat("EEE");
    dayValue = dayFormat.format(inTime);

    DateFormat timeFormat = DateFormat("hh:mm a");
    clockInValue = timeFormat.format(inTime);

    if (widget.empHistoryData.outTime != null) {
      DateTime outTime = DateTime.parse(widget.empHistoryData.outTime!);
      clockOutValue = timeFormat.format(outTime);

      Duration difference = outTime.difference(inTime);
      String formattedHours = difference.inHours.toString().padLeft(2, '0');
      String formattedMinutes = (difference.inMinutes % 60).toString().padLeft(2, '0');
      workingHrValue = "${formattedHours}h ${formattedMinutes}m";
    } else {
      clockOutValue = '-';
      workingHrValue = '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 10.h, bottom: 10.h, left: 15.w, right: 0),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clock In
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.login, size: 20.w, color: Colors.green),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clock In:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    '$clockInValue',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6.h),
                              // Fixed In Address Section
                            ],
                          ),
                        ),
                      ],
                    ),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_sharp, size: 20.w, color: Colors.green),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'In Address: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.sp,
                                        color: Colors.black,
                                      ),
                                    ),
                                    TextSpan(
                                      text: widget.empHistoryData.inLocAddInfo?.isNotEmpty == true
                                          ? widget.empHistoryData.inLocAddInfo!
                                          : 'Address not available',
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10.h),

                    // Clock Out
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.logout, size: 20.w, color: Colors.red),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clock Out:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  Expanded(
                                    child: Text(
                                      '$clockOutValue',
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6.h),
                            ],
                          ),
                        ),
                      ],
                    ),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_sharp, size: 20.w, color: Colors.red),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Out Address: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.sp,
                                        color: Colors.black,
                                      ),
                                    ),
                                    TextSpan(
                                      text: widget.empHistoryData.outLocAddInfo?.isNotEmpty == true
                                          ? widget.empHistoryData.outLocAddInfo!
                                          : 'Address not available',
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10.h),

                    // Working Hours
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.access_time, size: 20.w, color: Colors.blue),
                        SizedBox(width: 12.w),
                        Text(
                          'Working Hours: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                        Text(
                          workingHrValue.isNotEmpty==true?workingHrValue:"Not Available",
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              // Date & Day Container
              Container(
                width: 100.w,
                height: 100.w,
                margin: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue[100]!),
                  borderRadius: BorderRadius.circular(8.r),
                  color: Colors.blue[100],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dateValue,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22.sp,
                      ),
                    ),
                    Text(
                      dayValue,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Divider(height: 1.h, color: Colors.grey[300]),
        ],
      ),
    );

  }
}
