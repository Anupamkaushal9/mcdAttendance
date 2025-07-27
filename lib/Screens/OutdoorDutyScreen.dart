import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'Widgets/GlassAppbar.dart';

class OutDoorDutyScreen extends StatefulWidget {
  const OutDoorDutyScreen({super.key});

  @override
  State<OutDoorDutyScreen> createState() => _OutDoorDutyScreenState();
}

class _OutDoorDutyScreenState extends State<OutDoorDutyScreen> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'MCD PRO', isLayoutScreen: false),
      body: Padding(
        padding:  EdgeInsets.only(left: 8.0,right: 8.0,bottom: 8.0,top: kToolbarHeight+5.h+ MediaQuery.of(context).padding.top),
        child:  Center(
            child: Text(style: TextStyle(fontSize: 20.sp,fontWeight: FontWeight.bold),
              "Coming Soon",
              textScaleFactor: 1,
            )),
      ),
    );
  }
}
