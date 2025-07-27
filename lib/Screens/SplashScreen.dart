import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:mcd_attendance/Model/DeviceRegistrationStatusModel.dart';
import 'package:permission_handler/permission_handler.dart';
import '../Helpers/ApiBaseHelper.dart';
import 'Widgets/DialogBox.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool isLoading = false;
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<EmployeeXML> empData = [];
  String? deviceIdentifier = "unknown";

  @override
  void initState() {
    super.initState();
    //requestPermissions();
     _checkInternetAndInitialize();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkInternetAndInitialize() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      showDialog(
          context: context,
          builder: (BuildContext context) => NoInternetDialog(
            onRetry: () => Platform.isAndroid
                ? FlutterExitApp.exitApp()
                : FlutterExitApp.exitApp(iosForceExit: true),
          ));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Image.asset(
            'assets/images/mcd-logo.png',
            height: height / 4,
            width: height / 4,
          ),
        ),
      ),
    );
  }

  Future<void> requestPermissions() async {
    // Request permissions for camera, storage, and photos
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      Permission.photos,
      Permission.location,
      Permission
          .locationWhenInUse, // Optional, if you need 'When In Use' permission
      Permission.locationAlways,
    ].request();

    // Check the status of each permission
    PermissionStatus? statusCamera = statuses[Permission.camera];
    PermissionStatus? statusStorage = statuses[Permission.storage];

    // Handle camera permission status
    if (statusCamera != PermissionStatus.granted) {
      if (statusCamera == PermissionStatus.denied) {
        print('Camera permission denied');
      } else if (statusCamera == PermissionStatus.permanentlyDenied) {
        print('Camera permission permanently denied');
        // Open app settings if permission is permanently denied
        //openAppSettings();
      }
    }
  }
}
