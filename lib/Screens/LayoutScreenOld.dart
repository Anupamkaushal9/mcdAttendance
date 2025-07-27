import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mcd_attendance/Screens/AttendanceHistoryScreen.dart';
import 'package:mcd_attendance/Screens/HomeScreen.dart';
import 'package:mcd_attendance/Screens/LoginScreen.dart';
import 'package:mcd_attendance/Screens/MenuScreen.dart';
import 'package:mcd_attendance/Screens/SettingScreen.dart';
import 'package:mcd_attendance/Screens/SettingScreenNew.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/AppBtn.dart';
import '../Helpers/Session.dart';
import '../Helpers/String.dart';
import '../Model/Employee.dart';
import '../Model/EmployeeHistoryModel.dart';
import 'NotificationScreen.dart';
import 'SupervisorScreen.dart';
import 'UserProfileScreen.dart';
import 'Widgets/DialogBox.dart';

class LayoutOldScreen extends StatefulWidget {
  final String bmid;
  final List<EmpData> empData;
  const LayoutOldScreen({super.key, required this.bmid, required this.empData});

  @override
  State<LayoutOldScreen> createState() => _LayoutOldScreenState();
}

class _LayoutOldScreenState extends State<LayoutOldScreen>
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

  Future<void> getUserFaceData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? base64Image = prefs
        .getString('user_face_data')
        ?.replaceFirst('data:image/jpeg;base64,', '');
    if (base64Image != null && base64Image.isNotEmpty) {
      userPhoto = base64Decode(base64Image);
    }
  }

  @override
  void initState() {
    setState(() {
      getUserFaceData().then((_) {
        _extractColors();
      });
      DateTime now = DateTime.now();
      currentYear = now.year;
      currentDay = now.day;
      month = now.month;
      currentMonth = DateFormat('MMMM').format(DateTime(currentYear, month));
      _isLoading = true;
    });
    _anController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation =
        CurvedAnimation(parent: _anController, curve: Curves.easeInOut);

    checkNetwork();
    getEmpHistory();

    buttonController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);

    buttonSqueezeanimation = Tween(
      begin: deviceWidth * 0.7,
      end: 50.0,
    ).animate(CurvedAnimation(
      parent: buttonController!,
      curve: const Interval(
        0.0,
        0.150,
      ),
    ));
    buttonSqueezeanimation = Tween(
      begin: deviceWidth * 0.7,
      end: 50.0,
    ).animate(CurvedAnimation(
      parent: buttonController!,
      curve: const Interval(
        0.0,
        0.150,
      ),
    ));
    getLastAttendance();
    super.initState();
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
    await apiBaseHelper.postAPICall(getEmpHistoryApi, parameter).then(
            (getData) {
          String error = getData['error'].toString();
          String? msg = getData['status'].toString();
          if (msg == 'TRUE') {
            var data = getData['attendanceXML']['attendanceList'];
            if (mounted) {
              setState(() {
                // empHistoryData = [EmpHistoryData.fromJson(data)];
                empHistoryData = data
                    .map<EmpHistoryData>((json) => EmpHistoryData.fromJson(json))
                    .toList();
                print('historyData =' + empHistoryData![0].inTime!);
                _isLoading = false;
              });
            }
          } else {
            _isLoading = false;
          }
        }, onError: (e) {
      SnackBar(content: Text(e.toString()!));
    });
  }

  getLastAttendance() async {
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "empGuid": empGuid,
    };
    await apiBaseHelper.postAPICall(lastAttendanceApi, parameter).then(
          (getData) {
        String error = getData['error']?.toString() ??
            ''; // Handle case where error key might be missing
        String status = getData['status']?.toString() ?? '';

        if (status == 'TRUE') {
          String inTime = getData['in_time']?.toString() ?? '';
          String outTime = getData['out_time']?.toString() ?? '';
          if (mounted) {
            setState(() {
              print('In Time: $inTime');
              print('Out Time: $outTime');
              if (inTime.isNotEmpty) {
                if (DateTime.now().day !=
                    DateTime.parse(inTime)
                        .day) //using this logic to set inTime and outTime empty after 12 am
                    {
                  setState(() {
                    inTiming = "";
                    outTiming = "";
                  });
                } else {
                  inTiming = inTime;
                  outTiming = outTime;
                }
              } else {
                inTiming = inTime;
                outTiming = outTime;
              }
              _isLoading = false;
            });
          }
        } else {
          // Handle NO RECORD FOUND or other error cases
          setState(() {
            _isLoading = false;
          });
          if (error.isNotEmpty) {
            // Show an appropriate message, maybe using a SnackBar or alert
            print('Error: $error');
          }
        }
      },
      onError: (e) {
        SnackBar(content: Text(e.toString())); // Show the error message
      },
    );
  }

  @override
  void dispose() {
    _anController.dispose();
    buttonController?.dispose();
    super.dispose();
  }


  Future<void> _extractColors() async {
    final PaletteGenerator paletteGenerator =
    await PaletteGenerator.fromImageProvider(
      MemoryImage(userPhoto!), // Replace with actual image path
    );

    setState(() {
      _gradientColors = [
        paletteGenerator.dominantColor?.color.withAlpha(10) ?? Colors.black,
        paletteGenerator.vibrantColor?.color.withAlpha(10)  ?? Colors.grey,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("MCD PRO"),
        centerTitle: true,
        // backgroundColor: const Color(0xffdff5ce),
      ),
      bottomNavigationBar: NavigationBar(
        // backgroundColor: const Color(0xffdff5ce),
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
            if (currentPageIndex == 2 || currentPageIndex == 0) {
              setState(() {
                getEmpHistory();
              });
            }
          });
        },
        indicatorColor: Colors.amber,
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.star),
            label: 'Supervisor',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.history),
            icon: Icon(Icons.history_outlined),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      body: !_isLoading
          ? _isNetworkAvail
          ? <Widget>[
        /// Home page
        HomeScreen(
          bmid: widget.bmid,
          employee: widget.empData,
          //empHistoryData: empHistoryData,
          inTime: inTiming,
          outTime: outTiming,
          day: currentDay,
        ),

        /// Notifications page
        const SupervisorScreen(),

        /// History page
        AttendanceHistoryScreen(
          //  empHistoryData: empHistoryData,
            currentYear: currentYear,
            currentMonth: currentMonth,
            month: month),

        /// Setting Page
        const SettingsScreenNew(empData: [],),
      ][currentPageIndex]
          : noInternet(context)
          : SizedBox(
        height: MediaQuery.of(context).size.height / 1.3,
        child: const Center(child: CircularProgressIndicator()),
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
    return Color.fromARGB(80, red, green, blue); // Alpha set to 80 for transparency
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
        backgroundColor:  randomColor!.withAlpha(180),
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
              _buildDrawerItem(context,Icons.person, "Profile"),
              const Divider(color: Colors.white54),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text("Communicate",
                    style: TextStyle(color: Colors.white70)),
              ),
              _buildDrawerItem(context,Icons.lock, "Privacy Policy"),
              _buildDrawerItem(context,Icons.phone, "Contact Us"),
              _buildDrawerItem(context,
                  Icons.info, "App Version ($appVersionFromDevice)"),
              const SizedBox(height: 20),
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
