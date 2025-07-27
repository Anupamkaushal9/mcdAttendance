import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mcd_attendance/Helpers/String.dart';
import 'package:mcd_attendance/Screens/DeRegisterHistoryScreen.dart';
import 'package:mcd_attendance/Screens/FaqScreen.dart';
import 'package:mcd_attendance/Screens/HelpDeskScreen.dart';
import 'package:mcd_attendance/Screens/HolidayListScreen.dart';
import 'package:mcd_attendance/Screens/LayoutScreen.dart';
import 'package:mcd_attendance/Screens/ManageLeavesScreen.dart';
import 'package:mcd_attendance/Screens/NewAvailableMeetingScreen.dart';
import 'package:mcd_attendance/Screens/NewAvailableTaskScreen.dart';
import 'package:mcd_attendance/Screens/NotificationScreen.dart';
import 'package:mcd_attendance/Screens/TransferHistoryScreen.dart';
import 'dart:math';

import 'package:mcd_attendance/Screens/ZonalReportScreen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  // List of menu items
  final List<MenuItem> servicesItems = [
    MenuItem(
      icon: Image.asset('assets/images/meeting.png', height: 50.h, width: 50.w),
      title: 'Meetings',
    ),
    MenuItem(
      icon: Image.asset('assets/images/my_task.png', height: 50.h, width: 50.w),
      title: 'My Tasks',
    ),
    MenuItem(
      icon: Image.asset('assets/images/holiday.png', height: 50.h, width: 50.w),
      title: 'Holidays List',
    ),
    // MenuItem(
    //   icon: Image.asset('assets/images/notification.png', height: 50.h, width: 50.w),
    //   title: 'Notifications',
    // ),
    MenuItem(
      icon: Image.asset('assets/images/manage_leaves.png', height: 50.h, width: 50.w),
      title: 'Manage Leaves',
    ),
  ];

  final List<MenuItem> supportItems = [
    MenuItem(
      icon: Image.asset('assets/images/helpSupport.png', height: 50.h, width: 50.w),
      title: 'Help Desk',
    ),
    MenuItem(
      icon: Image.asset('assets/images/faqs.png', height: 50.h, width: 50.w),
      title: 'FAQs',
    ),
  ];

  final List<MenuItem> misReportItems = [
    MenuItem(
      icon: Image.asset('assets/images/zonal.png',height: 50.h, width: 50.w),
      title: 'Zonal Report',
    ),
  ];

  // Function to generate random color
  Color _generateRandomColor() {
    Random random = Random();
    return Color.fromRGBO(
      random.nextInt(76) + 180, // Red value (180 to 255)
      random.nextInt(76) + 180, // Green value (180 to 255)
      random.nextInt(76) + 180, // Blue value (180 to 255)
      1.0, // Opacity value (1.0 = fully opaque)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16), // Padding for responsive design
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Services
              Text(
                "Services",
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Divider(thickness: 1,color: Colors.grey.shade300,),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16.w,
                  mainAxisSpacing: 16.h,
                  childAspectRatio: 1.2,
                ),
                itemCount: servicesItems.length,
                itemBuilder: (context, index) {
                  final menuItem = servicesItems[index];
                  Color randomColor = _generateRandomColor();

                  return GestureDetector(
                    onTap: () {
                      if (menuItem.title == 'Meetings') {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const NewAvailableMeetingScreen(payLoad: '',)));
                      } else if (menuItem.title == 'Attendance') {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => LayoutScreen(bmid: userBmid, empData: empTempData,)));
                      } else if (menuItem.title == 'My Tasks') {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => NewAvailableTaskScreen()));
                      }else if (menuItem.title == 'Manage Leaves') {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ManageLeavesScreen()));
                      }
                      else if (menuItem.title == 'Outdoor Duty') {
                      }
                      else if (menuItem.title == 'Notifications') {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const NotificationScreen()));
                      }
                      else if (menuItem.title == 'Holidays List') {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const HolidayListScreen()));
                      }
                    },
                    child: Card(
                      elevation: 4,
                      shadowColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      color: Colors.white,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          menuItem.icon,
                          SizedBox(height: 8.h),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              menuItem.title,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 20.h),

              // Section 2: Support
              Text(
                "Support",
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Divider(thickness: 1,color: Colors.grey.shade300,),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16.w,
                  mainAxisSpacing: 16.h,
                  childAspectRatio: 1.2,
                ),
                itemCount: supportItems.length,
                itemBuilder: (context, index) {
                  final menuItem = supportItems[index];
                  Color randomColor = _generateRandomColor();

                  return GestureDetector(
                    onTap: () {
                      if (menuItem.title == 'Help Desk') {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const HelpDeskScreen()));
                      } else if (menuItem.title == 'FAQs') {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const FAQScreen()));
                      }
                    },
                    child: Card(
                      elevation: 4,
                      shadowColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      color: Colors.white,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          menuItem.icon,
                          SizedBox(height: 8.h),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              menuItem.title,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 20.h),

              // Section 3: MIS Report
              // Text(
              //   "MIS Report",
              //   style: TextStyle(
              //     fontSize: 22.sp,
              //     fontWeight: FontWeight.bold,
              //   ),
              // ),
              // Divider(thickness: 1,color: Colors.grey.shade300,),
              // GridView.builder(
              //   shrinkWrap: true,
              //   physics: const NeverScrollableScrollPhysics(),
              //   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              //     crossAxisCount: 3,
              //     crossAxisSpacing: 16.w,
              //     mainAxisSpacing: 16.h,
              //     childAspectRatio: 1.2,
              //   ),
              //   itemCount: misReportItems.length,
              //   itemBuilder: (context, index) {
              //     final menuItem = misReportItems[index];
              //     Color randomColor = _generateRandomColor();
              //
              //     return GestureDetector(
              //       onTap: () {
              //         if (menuItem.title == 'Zonal Report') {
              //           Navigator.push(context,
              //               MaterialPageRoute(builder: (_) => const ZonalReportScreen()));
              //         }
              //       },
              //       child: Card(
              //         elevation: 4,
              //         shadowColor: Colors.teal,
              //         shape: RoundedRectangleBorder(
              //           borderRadius: BorderRadius.circular(12.r),
              //         ),
              //         color: Colors.white,
              //         child: Column(
              //           mainAxisAlignment: MainAxisAlignment.center,
              //           children: [
              //             menuItem.icon,
              //             SizedBox(height: 8.h),
              //             Text(
              //               menuItem.title,
              //               style: TextStyle(
              //                 fontSize: 14.sp,
              //                 fontWeight: FontWeight.bold,
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //     );
              //   },
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

class MenuItem {
  final Image icon;
  final String title;

  MenuItem({required this.icon, required this.title});
}
