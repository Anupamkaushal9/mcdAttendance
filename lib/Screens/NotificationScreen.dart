import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'Widgets/GlassAppbar.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'MCD SMART', isLayoutScreen: false),
      body: Padding(
        padding:  EdgeInsets.only(left: 8.0,right: 8.0,bottom: 8.0,top: kToolbarHeight+5.h+ MediaQuery.of(context).padding.top),
        child: const Center(
            child: Text(
          "No notification available",
          textScaleFactor: 1,
        )),
      ),
    );
  }
}
