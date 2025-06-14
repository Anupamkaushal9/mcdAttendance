import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mcd_attendance/Screens/AttendanceHistoryScreen.dart';
import 'package:mcd_attendance/Screens/HomeScreen.dart';
import 'package:mcd_attendance/Screens/LoginScreen.dart';
import 'package:mcd_attendance/Screens/MenuScreen.dart';
import 'package:mcd_attendance/Screens/SettingScreen.dart';
import 'package:mcd_attendance/Screens/SettingScreenNew.dart';
import 'package:motion_tab_bar/MotionTabBar.dart';
import 'package:motion_tab_bar/MotionTabBarController.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/AppBtn.dart';
import '../Helpers/Session.dart';
import '../Helpers/String.dart';
import '../Model/Employee.dart';
import '../Model/EmployeeHistoryModel.dart';
import '../providers/BottomNavProvider.dart';
import 'NotificationScreen.dart';
import 'SupervisorScreen.dart';
import 'UserProfileScreen.dart';
import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class LayoutScreen extends StatefulWidget {
  final String bmid;
  final List<EmpData> empData;
  const LayoutScreen({super.key, required this.bmid, required this.empData});

  @override
  State<LayoutScreen> createState() => _LayoutScreenState();
}

class _LayoutScreenState extends State<LayoutScreen>
    with TickerProviderStateMixin {
  int currentPageIndex = 0;
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<EmpData> empData = [];
  bool _isNetworkAvail = true;
  bool _isLoading = true;
  Animation? buttonSqueezeanimation;
  AnimationController? buttonController;
  double deviceWidth =
      WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width;
  late AnimationController _anController;
  late Animation<double> _animation;
  int currentYear = 0;
  int month = 0;
  int currentDay = 0;
  String currentMonth = '';
  List<EmpHistoryData>? empHistoryData = [];
  Color _drawerColor = Colors.black.withOpacity(0.5); // Initial transparency
  List<Color> _gradientColors = [Colors.black, Colors.grey];
  MotionTabBarController? _motionTabBarController;
  Color? startColor;
  Color? endColor;

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

  Future<void> getUserFaceData() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // Check if prefs is null (though unlikely with SharedPreferences)
      if (prefs == null) {
        _showNullValueError("Failed to access device storage");
        return;
      }

      // Get the stored image data with null check
      String? base64Image = prefs.getString('user_face_data');

      // If no image data found, we can return silently or set a default
      if (base64Image == null || base64Image.isEmpty) {
        // Optionally set a default image or leave userPhoto as null
        // userPhoto = defaultPhotoBytes; // if you have a default
        return;
      }

      // Safely remove the prefix if it exists
      final String prefix = 'data:image/jpeg;base64,';
      if (base64Image.startsWith(prefix)) {
        base64Image = base64Image.replaceFirst(prefix, '');
      }

      // Verify the string is not empty after prefix removal
      if (base64Image.isEmpty) {
        _showNullValueError("Invalid image data format");
        return;
      }

      try {
        // Attempt to decode the base64 string
        userPhoto = base64Decode(base64Image);

        // Verify the decoded bytes are valid
        if (userPhoto == null || userPhoto!.isEmpty) {
          _showNullValueError("Failed to decode image data");
          userPhoto = null;
        }
      } catch (e) {
        _showNullValueError("Invalid image data format: ${e.toString()}");
        userPhoto = null;
      }
    } catch (e) {
      _showNullValueError("Error accessing user data: ${e.toString()}");
      userPhoto = null;
    }
  }


  @override
  void initState() {
    super.initState();
    startColor = getRandomMediumColor();
    endColor = getRandomMediumColor();
    // Initialize tab bar controller
    _motionTabBarController = MotionTabBarController(
      initialIndex: 0,
      length: 4,
      vsync: this,
    );

    // Set controller and index in Provider after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bottomNavProvider =
      Provider.of<BottomNavigationProvider>(context, listen: false);
      bottomNavProvider.currentIndex = 0;
      bottomNavProvider.setTabController(_motionTabBarController!);
    });

    // Initialize date and employee data
    final now = DateTime.now();
    currentYear = now.year;
    currentDay = now.day;
    month = now.month;
    currentMonth = DateFormat('MMMM').format(DateTime(currentYear, month));
    empTempData = widget.empData;
    _isLoading = true;

    // Async data fetching — safe from setState issues
    getUserFaceData();

    // Animations
    _anController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _anController,
      curve: Curves.easeInOut,
    );

    buttonController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    buttonSqueezeanimation = Tween(
      begin: deviceWidth * 0.7,
      end: 50.0,
    ).animate(CurvedAnimation(
      parent: buttonController!,
      curve: const Interval(0.0, 0.150),
    ));

    // Other async calls
    checkNetwork();
    getEmpHistory();
    getLastAttendance();
  }


  Future<void> checkNetwork() async {
    _isNetworkAvail = await isNetworkAvailable();

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  getEmpHistory() async {
    print("Layout History is running");
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "orgUnitGuid": "2493c2cd-5510-451d-9afe-e1a1468d0ac2",
      "month": "$month",
      "year": "$currentYear",
      "empGuid": empGuid
    };

    try {
      await apiBaseHelper.postAPICall(getEmpHistoryApi, parameter).then(
              (getData) {
            // Check for null response
            if (getData == null) {
              _showNullValueError("API returned null response....getHistory API");
              return;
            }

            String error = getData['error'].toString();
            String? msg = getData['status'].toString();

            if (msg == 'TRUE') {
              // Check if attendanceXML exists
              if (!getData.containsKey('attendanceXML')) {
                _showNullValueError("Missing attendance data in API response....getHistory API");
                return;
              }

              var attendanceXML = getData['attendanceXML'];
              // Check if attendanceList exists
              if (attendanceXML == null || !attendanceXML.containsKey('attendanceList')) {
                _showNullValueError("Missing attendance list in API response....getHistory API");
                return;
              }

              var data = attendanceXML['attendanceList'];
              if (mounted) {
                setState(() {
                  try {
                    empHistoryData = data
                        .map<EmpHistoryData>((json) => EmpHistoryData.fromJson(json))
                        .toList();
                    isFreshUser = empHistoryData == null || empHistoryData!.isEmpty;
                    print('historyData =' + empHistoryData![0].inTime!);
                    _isLoading = false;
                  } catch (e) {
                    _showNullValueError("Error parsing attendance data: ${e.toString()}....getHistory API");
                    empHistoryData = [];
                    _isLoading = false;
                  }
                });
              }
            } else {
              print(error+msg);
              _isLoading = false;
            }
          },
          onError: (e) {
            _showNullValueError('$e....getHistory API');
          }
      );
    } catch (e) {
      _showNullValueError(e.toString());
    }
  }

  Future<void> _clearPreference() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.clear();
  }


  getLastAttendance() async {
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "empGuid": empGuid,
    };

    try {
      await apiBaseHelper.postAPICall(lastAttendanceApi, parameter).then(
            (getData) {
          // First check if getData is null
          if (getData == null) {
            _showNullValueError("API returned null response.....getLastAttendance API");
            return;
          }

          String error = getData['error']?.toString() ?? '';
          String status = getData['status']?.toString() ?? '';

          if (status == 'TRUE') {
            // Check if in_time/out_time exist in response
            if (!getData.containsKey('in_time') || !getData.containsKey('out_time')) {
              _showNullValueError("Missing time data in API response.....getLastAttendance API");
              return;
            }

            String inTime = getData['in_time']?.toString() ?? '';
            String outTime = getData['out_time']?.toString() ?? '';

            if (mounted) {
              setState(() {
                print('In Time: $inTime');
                print('Out Time: $outTime');

                DateTime now = DateTime.now();

                if (inTime.isNotEmpty && outTime.isNotEmpty) {
                  try {
                    DateTime inDateTime = DateTime.parse(inTime);
                    if (inDateTime.year != now.year ||
                        inDateTime.month != now.month ||
                        inDateTime.day != now.day) {
                      inTiming = '';
                      outTiming = '';
                    } else {
                      inTiming = inTime;
                      outTiming = outTime;
                    }
                  } catch (e) {
                    _showNullValueError("Invalid date format in API response.....getLastAttendance API");
                    inTiming = '';
                    outTiming = '';
                  }
                } else if (inTime.isNotEmpty && outTime.isEmpty) {
                  try {
                    DateTime inDateTime = DateTime.parse(inTime);
                    Duration difference = now.difference(inDateTime);
                    if (difference.inHours >= 20) {
                      inTiming = '';
                      outTiming = '';
                    } else {
                      inTiming = inTime;
                      outTiming = outTime;
                    }
                  } catch (e) {
                    _showNullValueError("Invalid date format in API response.....getLastAttendance API");
                    inTiming = '';
                    outTiming = '';
                  }
                } else {
                  inTiming = '';
                  outTiming = '';
                }
                _isLoading = false;
              });
            }
          } else {
            if (error == 'NO RECORD FOUND.') {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });

                // 👇 Only show error if user has history
                if (!isFreshUser) {
                  _clearPreference();
                  _showNullValueError("No attendance record found.....getLastAttendance API");
                }
              }
            }else if (error.isNotEmpty) {
              _showNullValueError('$error$status.....getLastAttendance API');
            } else {
              _showNullValueError("Unknown error occurred.....getLastAttendance API");
            }
          }
        },
        onError: (e) {
          if (mounted) {
            _showNullValueError('$e.....getLastAttendance API');
          }
        },
      );
    } catch (e) {
      if (mounted) {
        _showNullValueError('$e.....getLastAttendance API');
      }
    }
  }



  @override
  void dispose() {
    _anController.dispose();
    buttonController?.dispose();
    _motionTabBarController!.dispose();
    super.dispose();
  }

  // Future<void> _extractColors() async {
  //   final PaletteGenerator paletteGenerator =
  //       await PaletteGenerator.fromImageProvider(
  //     MemoryImage(userPhoto!), // Replace with actual image path
  //   );
  //
  //   setState(() {
  //     _gradientColors = [
  //       paletteGenerator.dominantColor?.color.withAlpha(10) ?? Colors.black,
  //       paletteGenerator.vibrantColor?.color.withAlpha(10) ?? Colors.grey,
  //     ];
  //   });
  // }

  String getAppBarTitle() {
    final bottomNavProvider = Provider.of<BottomNavigationProvider>(context);
    switch (bottomNavProvider.currentIndex) {
      case 1:
        return "MCD SMART - ATTENDANCE";
      case 2:
        return "MCD SMART - SERVICES";
      case 3:
        return "MCD SMART - SETTINGS";
      default:
        return "MCD SMART";
    }
  }

  Color getRandomMediumColor() {
    final random = Random();
    // Slightly darker than light colors: range 100–200
    int r = 100 + random.nextInt(100);
    int g = 100 + random.nextInt(100);
    int b = 100 + random.nextInt(100);
    return Color.fromARGB(255, r, g, b);
  }

  @override
  Widget build(BuildContext context) {
    final bottomNavProvider = Provider.of<BottomNavigationProvider>(context);
    // Define list of screens corresponding to each tab
    final List<Widget> pages = [
      HomeScreen(
          bmid: userBmid,
          employee: widget.empData,
          empHistoryData: empHistoryData,
          day: currentDay), // Screen for Meetings
      const SupervisorScreen(),
      const MenuScreen(), // Screen for Notifications

      // AttendanceHistoryScreen(
      //   empHistoryData: empHistoryData,
      //     currentMonth: currentMonth,
      //     currentYear: currentYear,
      //     month: month), // Screen for My Tasks
      SettingsScreenNew(
        empData: widget.empData,
      ),
    ];
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar:  GlassAppBar(title: getAppBarTitle(),isLayoutScreen: true,),
      body: !_isLoading
          ? _isNetworkAvail
              ? pages[bottomNavProvider
                  .currentIndex] // Load the correct screen based on current index
              : noInternet(context)
          : Center(
              child: LottieBuilder.asset(
            'assets/animations/loading_animation.json',
            height: 50.h,
            width: 50.w,
          )),
      bottomNavigationBar: MotionTabBar(
        textStyle: TextStyle(fontSize: 16.sp),
        controller: _motionTabBarController,
        initialSelectedTab: "Home", // The initial tab to select
        labels: const [
          "Home",
          "Attendance",
          "Services",
          "Settings",
        ],
        icons: const [
          Icons.home,
          Icons.person_pin,
          Icons.star,
          Icons.settings,
        ],
        tabSize: 50, // Set tab size
        tabBarHeight: 60, // Set height of the tab bar
        tabIconColor: const Color(0xff111184),
        tabIconSize: 28.0,
        tabIconSelectedSize: 26.0,
        tabSelectedColor: const Color(0xff111184),
        tabIconSelectedColor: Colors.white,
        tabBarColor: Colors.white30,
        onTabItemSelected: (int index) {
          // setState(() {
          //   currentPageIndex = index;
          //   // Additional logic for specific pages if needed
          //   if (currentPageIndex == 0 ) {
          //     getEmpHistory(); // Example: You can add logic based on selected index
          //   }
          // });
          bottomNavProvider.currentIndex = index;
          if (index == 0) {
            getEmpHistory();
            getLastAttendance();
          }
        },
      ),
    );
  }

  Future<void> _playAnimation() async {
    try {
      await buttonController!.forward();
    } on TickerCanceled {}
  }

  Widget noInternet(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.only(top: kToolbarHeight),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          noIntImage(),
          noIntText(context),
          noIntDec(context),
          AppBtn(
            title: getTranslated(context, 'TRY_AGAIN_INT_LBL'),
            btnAnim: buttonSqueezeanimation,
            btnCntrl: buttonController,
            onBtnSelected: () async {
              _playAnimation();

              Future.delayed(const Duration(seconds: 2)).then((_) async {
                _isNetworkAvail = await isNetworkAvailable();
                if (_isNetworkAvail) {
                  Navigator.pushReplacement(
                      context,
                      CupertinoPageRoute(
                          builder: (BuildContext context) => super.widget));
                } else {
                  await buttonController!.reverse();
                  if (mounted) setState(() {});
                }
              });
            },
          )
        ]),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  final List<Color> gradientColors;
  Color? randomColor;
  AppDrawer({required this.gradientColors});

  Color getRandomDarkColor() {
    final Random random = Random();

    // Generate RGB values between 0 and 100 for a dark color
    int red = random.nextInt(100);
    int green = random.nextInt(100);
    int blue = random.nextInt(100);

    // Return a color with alpha set to 80 (semi-transparent)
    return Color.fromARGB(
        80, red, green, blue); // Alpha set to 80 for transparency
  }

  @override
  Widget build(BuildContext context) {
    randomColor = getRandomDarkColor();
    return Theme(
      data: Theme.of(context).copyWith(
        // Set the transparency here
        canvasColor: Colors
            .transparent, //or any other color you want. e.g Colors.blue.withOpacity(0.5)
      ),
      child: Drawer(
        elevation: 5, // Remove shadow
        backgroundColor: randomColor!.withAlpha(180),
        child: Container(
          decoration: const BoxDecoration(
            // gradient: LinearGradient(
            //   colors: gradientColors,
            //   begin: Alignment.topLeft,
            //   end: Alignment.bottomRight,
            // ),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Colors.transparent),
                accountName: Text(empName, style: TextStyle(fontSize: 18)),
                accountEmail: Text(userBmid),
                currentAccountPicture: CircleAvatar(
                  backgroundImage:
                      MemoryImage(userPhoto!), // Replace with actual image
                ),
              ),
              _buildDrawerItem(context, Icons.person, "Profile"),
              const Divider(color: Colors.white54),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text("Communicate",
                    style: TextStyle(color: Colors.white70)),
              ),
              _buildDrawerItem(context, Icons.lock, "Privacy Policy"),
              _buildDrawerItem(context, Icons.phone, "Contact Us"),
              _buildDrawerItem(
                  context, Icons.info, "App Version ($appVersionFromDevice)"),
              SizedBox(height: 20.h),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: BorderSide(color: Colors.white),
                  ),
                  onPressed: () {
                    showDialog(
                      barrierDismissible: true,
                      context: context,
                      builder: (_) => const LogoutConfirmationDialog(),
                    );
                  },
                  child:
                      Text("SIGN OUT", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: TextStyle(color: Colors.white)),
      onTap: () {
        if (title == 'Profile') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(),
            ),
          );
        }
        // Handle navigation
      },
    );
  }
}
