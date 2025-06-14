import 'package:flutter/widgets.dart';

// MediaQuery class to handle different device properties
class MediaQueries {
  // Screen width
  static double get screenWidth => MediaQueryData.fromWindow(WidgetsBinding.instance.window).size.width;

  // Screen height
  static double get screenHeight => MediaQueryData.fromWindow(WidgetsBinding.instance.window).size.height;

  // Device Pixel Ratio (DPR)
  static double get devicePixelRatio => MediaQueryData.fromWindow(WidgetsBinding.instance.window).devicePixelRatio;

  // Example: Check if the screen is in portrait mode
  static bool get isPortrait => screenHeight > screenWidth;

  // Example: Check if the screen is in landscape mode
  static bool get isLandscape => screenWidth > screenHeight;

  // Custom method to get the scale factor based on width
  static double get scaleFactor {
    if (screenWidth < 600) {
      return 1.0; // For small devices like phones
    } else if (screenWidth >= 600 && screenWidth < 1024) {
      return 1.2; // For medium devices like tablets
    } else {
      return 1.5; // For large devices like tablets and desktops
    }
  }

  // Example of a method to check if the device has high DPI
  static bool get isHighDpi => devicePixelRatio > 2.0;
}
