import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Helpers/Constant.dart';
import 'package:mcd_attendance/Model/HolidayDataModel.dart';
import 'package:http/http.dart' as http;

import '../Helpers/String.dart';
import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class HolidayListScreen extends StatefulWidget {
  const HolidayListScreen({super.key});

  @override
  State<HolidayListScreen> createState() => _HolidayListScreenState();
}

class _HolidayListScreenState extends State<HolidayListScreen> {
  bool isLoading = false;
  List<Holiday> holidays = [];

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

  Future<void> fetchHolidays() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    const String url = newBaseUrl;
    const String token = 'eyJhbGciOiJIUzI1NiJ9.e30.g2PzdcLXSunm0_ZW-5d9ptZSpeXZi0qsh_sTuTTojRs';

    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    var request = http.Request('GET', Uri.parse(url));
    var body = json.encode({
      "module": "holiday",
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

        List<dynamic> holidaysJson = data['data'] ?? [];

        if (holidaysJson is List) {
          if (mounted) {
            setState(() {
              holidays = holidaysJson
                  .map((json) => Holiday.fromJson(json))
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
              (Platform.isAndroid)?FlutterExitApp.exitApp():FlutterExitApp.exitApp(iosForceExit: true);
            },
          );
        },
      );
      return;
    }
    fetchHolidays();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'MCD PRO', isLayoutScreen: false),
      body: (!isLoading)?ListView.builder(
        itemCount: holidays.length,
        itemBuilder: (context, index) {
          final holiday = holidays[index];

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            color: Colors.grey.shade100,
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              title: Text(
                holiday.holidayOccasion!,
                style:  TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                'Date: ${holiday.holidayDate}\n'
                    'Type: ${holiday.masterDescriptionText}',
                style:  TextStyle(
                  fontSize: 14.sp,
                  color: Colors.black54,
                ),
              ),
              trailing: Icon(
                holiday.masterDescriptionText == 'Gazetted Holiday'
                    ? Icons.event
                    : Icons.event_available,
                color: holiday.masterDescriptionText == 'Gazetted Holiday'
                    ? Colors.green
                    : Colors.orange,
              ),
              onTap: () {
              },
            ),
          );
        },
      ):Center(
        child: LottieBuilder.asset(
          'assets/animations/loading_animation.json',
          height: 50.h,
          width: 50.w,
        ),
      ),
    );
  }
}