import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:mcd_attendance/Helpers/NotificationService.dart';
import 'package:mcd_attendance/Screens/LayoutScreen.dart';
import 'package:mcd_attendance/Screens/SettingScreenNew.dart';
import 'package:motion_tab_bar/MotionTabBar.dart';
import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/String.dart';
import '../Model/Employee.dart';
import 'package:motion_tab_bar/MotionTabBarController.dart';

import 'MenuScreen.dart';

class NewLayoutScreen extends StatefulWidget {
  const NewLayoutScreen({super.key});

  @override
  State<NewLayoutScreen> createState() => _NewLayoutScreenState();
}

class _NewLayoutScreenState extends State<NewLayoutScreen>
    with TickerProviderStateMixin {
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<EmpData> empData = [];
  bool isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final bmidController = TextEditingController();
  MotionTabBarController? _motionTabBarController;

  // List of screens for bottom navigation
  final List<Widget> _screens = [
    const MenuScreen(),
    LayoutScreen(
        bmid: userBmid,
        empData: empTempData), // Placeholder until dynamic data is available
     const SettingsScreenNew(empData: [],)
  ];

  @override
  void initState() {
    super.initState();
    _motionTabBarController = MotionTabBarController(
      initialIndex: 0, // Start at the first tab by default
      length: 2, // Number of menu items
      vsync: this,
    );
    NotificationService.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("MCD SMART"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => (Platform.isAndroid)?FlutterExitApp.exitApp():FlutterExitApp.exitApp(iosForceExit: true),
        ),
      ),
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _motionTabBarController,
        children: const <Widget>[
          MenuScreen(), // Screen for Meetings
          SettingsScreenNew(empData: [],), // Screen for Notifications
        ],
      ),
      bottomNavigationBar: MotionTabBar(
        controller:
            _motionTabBarController, // Controller to switch tabs programmatically
        initialSelectedTab: "Home", // Start with Meetings tab
        useSafeArea: true, // Default: true, wrap inside safe area
        labels: const [
          "Home",
          "Settings",
        ],
        icons: const [
          Icons.home, // Icon for Meetings
          Icons.settings,
        ], // Icon for Notification
        tabSize: 60,
        tabBarHeight: 65,
        textStyle: const TextStyle(
          fontSize: 12,
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
        tabIconColor: Colors.blue[900],
        tabIconSize: 28.0,
        tabIconSelectedSize: 26.0,
        tabSelectedColor: Colors.blue[900],
        tabIconSelectedColor: Colors.white,
        tabBarColor: Colors.white30,
        onTabItemSelected: (int value) {
          setState(() {
            _motionTabBarController!.index = value; // Update selected tab
          });
        },
      ),
    );
  }
}
