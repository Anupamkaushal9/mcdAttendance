// lib/location_utils.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:detect_fake_location/detect_fake_location.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> checkForMockLocation(BuildContext context) async {
  // Check location services are enabled
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    print("Location services are disabled.");
    return;
  }

  // Check for location permission
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      print("Location permissions are denied.");
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    showOpenSettingsDialog(context, "Location required");
    print("Location permissions are permanently denied.");
    return;
  }

  // Get the current position and check if it is a mock location
  Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);

  // Check if the position comes from a mock provider (fake GPS)
  bool isFakeLocation = await DetectFakeLocation().detectFakeLocation();
  if (position.isMocked||isFakeLocation) {
    print("Mock location detected!");
    showMockLocationDialog(context);
  }


}

void showOpenSettingsDialog(BuildContext context, String permissionName) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent dismissal by tapping outside
    builder: (BuildContext context) {
      return WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Permission Required'),
          content: Text(
            'The $permissionName permission has been permanently denied. '
            'Please enable it from the app settings to continue.',
          ),
          actions: <Widget>[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  await openAppSettings();
                  (Platform.isAndroid)
                      ? FlutterExitApp.exitApp()
                      : FlutterExitApp.exitApp(iosForceExit: true);
                },
                child: const Text(
                  "Open Settings",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          ],
        ),
      );
    },
  );
}

// Show dialog for mock location detection
showMockLocationDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: SvgPicture.asset(
                  'assets/images/fake_location.svg', // Put the correct asset path for no internet animation
                  height: 100.h,
                ),
              ),
              SizedBox(height: 5.h),
               Center(
                child: Text(
                  textAlign: TextAlign.center,
                  "Please disable mock locations in Developer Options to continue.",
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold,fontSize: 20.sp),
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff111184),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    (Platform.isAndroid)
                        ? FlutterExitApp.exitApp()
                        : FlutterExitApp.exitApp(
                            iosForceExit: true); // Close the dialog
                  },
                  child: Text(
                    "Okay",
                    style: TextStyle(fontSize: 16.sp, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
