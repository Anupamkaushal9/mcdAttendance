import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Helpers/Constant.dart';
import 'package:mcd_attendance/Model/DeregistrationHistoryModel.dart';
import 'package:mcd_attendance/Model/HolidayDataModel.dart';
import 'package:http/http.dart' as http;

import '../Helpers/String.dart';
import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class DeregisterHistoryScreen extends StatefulWidget {
  const DeregisterHistoryScreen({super.key});

  @override
  State<DeregisterHistoryScreen> createState() =>
      _DeregisterHistoryScreenState();
}

class _DeregisterHistoryScreenState extends State<DeregisterHistoryScreen> {
  bool isLoading = false;
  List<DeregistrationRecord> records = [];

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

  Future<void> fetchDeregisterHistoryRecords() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    const String url = newBaseUrl;
    const String token =
        'eyJhbGciOiJIUzI1NiJ9.e30.g2PzdcLXSunm0_ZW-5d9ptZSpeXZi0qsh_sTuTTojRs';

    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    var request = http.Request('GET', Uri.parse(url));
    var body = json.encode({
      "module": "device",
      "event": "deregistration_history",
      "params": {"emp_bmid": userBmid}
    });

    request.body = body;
    request.headers.addAll(headers);

    try {
      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> data = json.decode(responseBody);

        List<dynamic> holidaysJson = data['data'] ?? [];

        if (holidaysJson is List) {
          if (mounted) {
            setState(() {
              records = holidaysJson
                  .map((json) => DeregistrationRecord.fromJson(json))
                  .toList();
            });
          }
        } else {
          _showNullValueError("fetchHolidays Api: 'data' is not a valid list.");
        }
      } else {
        _showNullValueError("fetchHolidays Api: HTTP ${response.statusCode}");
      }
    } catch (e) {
      _showNullValueError("fetchHolidays Api Exception: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    _checkInternetAndInitialize();
    super.initState();
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
    fetchDeregisterHistoryRecords();
  }

  // Helper method to get color based on status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

// Helper widget for consistent info rows
  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black87,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                TextSpan(
                  text: value ?? 'N/A',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'MCD PRO', isLayoutScreen: false),
      body: (!isLoading)
          ? (records.isNotEmpty)
              ? ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final statusColor = _getStatusColor(record.status!);

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.4),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Card(
                        elevation: 0,
                        color: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () {},
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: statusColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    record.status!,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Information Rows
                                _buildInfoRow(Icons.calendar_month_outlined,
                                    'Date', record.createdOn),
                                const SizedBox(height: 8),
                                _buildInfoRow(Icons.badge_outlined, 'BMID',
                                    record.empBmid.toString()),
                                const SizedBox(height: 8),
                                _buildInfoRow(Icons.comment_outlined, 'Remarks',
                                    record.remark),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : const Center(
                  child: Text("No records found"),
                )
          : Center(
              child: LottieBuilder.asset(
                'assets/animations/loading_animation.json',
                height: 50.h,
                width: 50.w,
              ),
            ),
    );
  }
}
