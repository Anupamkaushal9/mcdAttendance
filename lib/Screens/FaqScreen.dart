import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Model/FaqDataModel.dart';
import '../Helpers/ApiBaseHelper.dart';
import 'package:http/http.dart' as http;

import '../Helpers/String.dart';
import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  bool _isNetworkAvail = true;
  bool isLoading = false;
  late List<FAQDataModel> faqList = [];
  int? _expandedIndex; // Track the expanded tile index

  @override
  void initState() {
    super.initState();
    _checkInternetAndInitialize(); // Fetch FAQs when the screen initializes
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

  Future<void> fetchFAQs() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    const String url = 'https://api.mcd.gov.in/app/request';
    const String token = 'eyJhbGciOiJIUzI1NiJ9.e30.g2PzdcLXSunm0_ZW-5d9ptZSpeXZi0qsh_sTuTTojRs';

    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    var request = http.Request('GET', Uri.parse(url));
    var body = json.encode({
      "module": "faq",
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

        List<dynamic> faqJson = data['data'] ?? [];

        if (mounted) {
          setState(() {
            faqList = faqJson
                .map((json) => FAQDataModel.fromJson(json))
                .toList();
          });
        }
      } else {
        _showNullValueError("fetchFAQs Api: Status code ${response.statusCode}");
      }
    } catch (e) {
      _showNullValueError("fetchFAQs Api Exception: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
    fetchFAQs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'MCD SMART', isLayoutScreen: false),
      body: isLoading
          ?  Center(child: LottieBuilder.asset('assets/animations/loading_animation.json',height: 50.h,width: 50.w,))
          : _isNetworkAvail
              ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ListView.builder(
                    itemCount: faqList.length,
                    itemBuilder: (context, index) {
                      bool isExpanded = _expandedIndex == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _expandedIndex = isExpanded ? null : index;
                          });
                        },
                        child: Card(
                          elevation: 2.0,
                          color: Colors.white60,
                          child: Column(
                            children: [
                              ListTile(
                                title: Text(
                                  faqList[index].faqQues ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                ),
                              ),
                              if (isExpanded)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 8.0),
                                  child: Text(
                                    faqList[index].faqAns ?? '',
                                    textAlign: TextAlign.justify,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              )
              : const Center(child: Text('Network Error!')),
    );
  }
}
