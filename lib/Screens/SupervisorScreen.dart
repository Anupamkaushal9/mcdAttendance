import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mcd_attendance/Screens/AttendanceHistoryScreen.dart';
import 'package:mcd_attendance/Screens/EmployeeListScreen.dart';
import 'package:mcd_attendance/Screens/LOPScreen.dart';
import 'package:mcd_attendance/Screens/ManageLeavesScreen.dart';
import 'package:mcd_attendance/Screens/OutdoorDutyScreen.dart';
import 'package:provider/provider.dart';

import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/String.dart';
import '../Model/EmployeeHistoryModel.dart';
import '../providers/BottomNavProvider.dart';
import 'DeRegisterHistoryScreen.dart';
import 'OuCheckerScreen.dart';
import 'TransferHistoryScreen.dart';
import 'Widgets/DialogBox.dart';

class SupervisorScreen extends StatefulWidget {
  const SupervisorScreen({super.key});

  @override
  State<SupervisorScreen> createState() => _SupervisorScreenState();
}

class _SupervisorScreenState extends State<SupervisorScreen> {
  int currentYear = 0;
  int month = 0;
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  bool _isLoading = false;
  List<EmpHistoryData>? empHistoryData = [];

  final List<MenuItem> menuItems = [
    MenuItem(
      icon: Image.asset('assets/images/self.png', height: 50.h, width: 50.w),
      title: 'Self',
    ),
    MenuItem(
      icon: Image.asset('assets/images/supervisor.png', height: 50.h, width: 50.w),
      title: 'Supervisor',
    ),
    MenuItem(
      icon: Image.asset('assets/images/clock_out.png', height: 50.h, width: 50.w),
      title: 'History', // Was 'Self History'
    ),
    MenuItem(
      icon: Image.asset('assets/images/clock_out.png', height: 50.h, width: 50.w),
      title: 'History', // Was 'SuperV History'
    ),
    MenuItem(
      icon: Image.asset('assets/images/device_history.png', height: 50.h, width: 50.w),
      title: 'De-Register History',
    ),
    // MenuItem(
    //   icon: Image.asset('assets/images/lop.png', height: 50.h, width: 50.w),
    //   title: 'LOP',
    // ),
    // MenuItem(
    //   icon: Image.asset('assets/images/outdoor.png', height: 50.h, width: 50.w),
    //   title: 'Outdoor Duty',
    // ),

    MenuItem(
      icon: Image.asset('assets/images/ou_checker.png', height: 50.h, width: 50.w),
      title: 'Ou Checker', // Was 'SuperV History'
    ),
    MenuItem(
      icon: Image.asset('assets/images/transfer_history.png', height: 50.h, width: 50.w),
      title: 'Transfer History',
    ),
  ];

  @override
  void initState() {
    currentYear = DateTime.now().year;
    month = DateTime.now().month;
    getEmpHistory();
    super.initState();

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

  Future<void> getEmpHistory() async {
    try {
      await Future.delayed(const Duration(seconds: 2));

      var parameter = {
        "orgUnitGuid": "2493c2cd-5510-451d-9afe-e1a1468d0ac2",
        "month": "$month",
        "year": "$currentYear",
        "empGuid": empGuid,
      };

      final getData = await apiBaseHelper.postAPICall(getEmpHistoryApi, parameter);

      final String status = getData['status'].toString();
      String error = getData['error'].toString();

      if (status == 'TRUE') {
        final data = getData['attendanceXML']['attendanceList'];

        if (mounted) {
          setState(() {
            empHistoryData = data
                .map<EmpHistoryData>((json) => EmpHistoryData.fromJson(json))
                .toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        if(!error.contains("NO RECORD FOUND."))
        {
          _showNullValueError("getEmpHistory Api : $error $status");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showNullValueError("getEmpHistory Exception: ${e.toString()}");
    }
  }


  @override
  Widget build(BuildContext context) {
    final bottomNavProvider = Provider.of<BottomNavigationProvider>(context, listen: false);

    final selfSectionItems = [
      menuItems[0], // Self
      menuItems[4], // Manage Leaves
      menuItems[5], // LOP
      menuItems[6], // Transfer history
      menuItems[2], // History (Self)
    ];

    final supervisorSectionItems = [
      menuItems[1], // Supervisor
      menuItems[3], // History (Supervisor)
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Self
              Text(
                "Self",
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
              ),
              Divider(thickness: 1, color: Colors.grey.shade300),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16.w,
                  mainAxisSpacing: 16.h,
                  childAspectRatio: 1.2,
                ),
                itemCount: selfSectionItems.length,
                itemBuilder: (context, index) {
                  final menuItem = selfSectionItems[index];
                  return buildMenuCard(menuItem, bottomNavProvider, context, section: 'Self');
                },
              ),

              SizedBox(height: 20.h),

              // Section 2: Supervisor
              Visibility(visible: hasSuperVisorAccess,
                child: Text(
                  "Supervisor",
                  style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
                ),
              ),
              Visibility(visible: hasSuperVisorAccess,
                  child: Divider(thickness: 1, color: Colors.grey.shade300)),
              Visibility(visible: hasSuperVisorAccess,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16.w,
                    mainAxisSpacing: 16.h,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: supervisorSectionItems.length,
                  itemBuilder: (context, index) {
                    final menuItem = supervisorSectionItems[index];
                    return buildMenuCard(menuItem, bottomNavProvider, context, section: 'Supervisor');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMenuCard(MenuItem menuItem, BottomNavigationProvider bottomNavProvider, BuildContext context, {required String section}) {
    return GestureDetector(
      onTap: () {
        if (menuItem.title == 'History') {
          if (section == 'Self') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AttendanceHistoryScreen(
                //  empHistoryData: empHistoryData,
                  currentMonth: DateTime.now().month.toString(),
                  currentYear: DateTime.now().year,
                  month: month,
                ),
              ),
            );
          } else if (section == 'Supervisor') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployeeListScreen(comingFrom: 'superHistory')),
            );
          }
        }
        else if (menuItem.title == 'Transfer History') {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TransferHistoryScreen()));
        }
        else if (menuItem.title == 'De-Register History') {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DeregisterHistoryScreen()));
        }
        else if(menuItem.title=='LOP')
        {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LOPScreen()),
          );
        }
        else if (menuItem.title == 'Ou Checker') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) =>  const OuCheckerScreen()),
          );
        }
        else if(menuItem.title=='Outdoor Duty')
        {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OutDoorDutyScreen()),
          );
        }
        else {
          switch (menuItem.title) {
            case 'Supervisor':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmployeeListScreen(comingFrom: 'superHome')),
              );
              break;
            case 'Self':
              bottomNavProvider.currentIndex = 0;
              break;
          }
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
                textAlign: TextAlign.center,
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
  }
}

class MenuItem {
  final Image icon;
  final String title;

  MenuItem({required this.icon, required this.title});
}
