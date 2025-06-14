import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';
import 'package:lottie/lottie.dart';
import '../Helpers/String.dart';
import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class HelpDeskScreen extends StatefulWidget {
  const HelpDeskScreen({super.key});

  @override
  State<HelpDeskScreen> createState() => _HelpDeskScreenState();
}

class _HelpDeskScreenState extends State<HelpDeskScreen> {
  bool isLoading = false;
  String helpData = '';

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

  Future<void> fetchHelpDeskContent() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    const String url = 'https://api.mcd.gov.in/app/request';
    const String token =
        'eyJhbGciOiJIUzI1NiJ9.e30.g2PzdcLXSunm0_ZW-5d9ptZSpeXZi0qsh_sTuTTojRs';

    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    var request = http.Request('GET', Uri.parse(url));
    var body = json.encode({
      "module": "helpdesk",
      "event": "view",
      "params": {"emp_bmid": userBmid}
    });

    request.body = body;
    request.headers.addAll(headers);

    try {
      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> data = json.decode(responseBody);

        var helpdeskData = data['data']['html'];

        if (helpdeskData != null) {
          if (mounted) {
            setState(() {
              helpData = helpdeskData.toString();
            });
          }
        }
      } else {
        _showNullValueError("fetchHelpDeskContent Api: HTTP ${response.statusCode}");
      }
    } catch (e) {
      _showNullValueError("fetchHelpDeskContent Api Exception: ${e.toString()}");
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
    fetchHelpDeskContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: 'MCD SMART', isLayoutScreen: false),
        body: (!isLoading)
            ? SingleChildScrollView(
                child: Padding(
                  padding:  EdgeInsets.only(left: 8.0,right: 8.0,bottom: 8.0,top: kToolbarHeight+5.h+ MediaQuery.of(context).padding.top),
                  child: Column(
                    children: [Html(data: helpData)],
                  ),
                ),
              )
            : Center(
                child: LottieBuilder.asset(
                  'assets/animations/loading_animation.json',
                  height: 50.h,
                  width: 50.w,
                ),
              ));
  }
}
