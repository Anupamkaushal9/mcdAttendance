import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart'as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Import ScreenUtils
import 'package:mcd_attendance/Helpers/Constant.dart';
import 'package:mcd_attendance/Screens/LayoutScreen.dart';
import 'package:mcd_attendance/Screens/NewLayoutScreen.dart';
import 'package:mcd_attendance/providers/BottomNavProvider.dart';
import 'package:motion_tab_bar/MotionTabBarController.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Helpers/ApiBaseHelper.dart';
import 'Helpers/NotificationService.dart';
import 'Helpers/String.dart';
import 'Model/DeviceRegistrationStatusModel.dart';
import 'Model/Employee.dart';
import 'Screens/LoginScreen.dart';
import 'Screens/SplashScreen.dart';
import 'Screens/Widgets/DialogBox.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:uuid/uuid.dart';

final navigatorKey = GlobalKey<NavigatorState>();
MotionTabBarController? motionTabBarController;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  tz.initializeTimeZones();
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp],
  ); // To turn off landscape mode
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => BottomNavigationProvider()),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(430, 932), // Set your design size
      minTextAdapt: true,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),///used for not to increase size of font by system settings
          child: MaterialApp(
            title: 'Attendance Application',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
            ),
            home: const MyHomePage(title: 'Attendance App'),
            navigatorKey: navigatorKey,
          ),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<EmpData> empData = [];
  bool _isLoading = true;
  List<EmployeeXML> empDeviceData = [];
  String? deviceIdentifier = "unknown";
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  bool isAppUpdated = true;

  @override
  void initState() {
    super.initState();
    initSequence();
  }

  Future<void> initSequence() async {
    await getAppVersion(); // Step 1

    bool isAppUpdated = await getAppVersionDataApi(context); // Step 2
    if (!isAppUpdated) return; // 🔁 Stop further flow if app is outdated

    await getDeviceIdentifierNew(); // Step 3
    await requestPermissions(context); // Step 4
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TODO: implement didChangeAppLifecycleState
    super.didChangeAppLifecycleState(state);
    // print("state is ${state.name}");
    if (state == AppLifecycleState.resumed) {
      requestPermissions(context);
    }
  }

  Future<void> requestPermissions(BuildContext context) async {
    // Request permissions for camera, storage, and photos
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      Permission.photos,
      Permission.location
    ].request();

    // Check the status of each permission
    PermissionStatus? statusCamera = statuses[Permission.camera];
    PermissionStatus? statusStorage = statuses[Permission.storage];
    PermissionStatus? statusLocation = statuses[Permission.location];
    // Handle camera permission status
    if (statusCamera != PermissionStatus.granted) {
      if (statusCamera == PermissionStatus.denied) {
        print('Camera permission denied');
      } else if (statusCamera == PermissionStatus.permanentlyDenied) {
        print('Camera permission permanently denied');
        // Show dialog that cannot be dismissed until user opens settings
        showOpenSettingsDialog(context, "Camera");
      }

    }
    else
    {
      getDeviceRegistrationStatus(deviceIdentifier!);
    }

    if (statusLocation != PermissionStatus.granted) {
      if (statusLocation == PermissionStatus.denied) {
        print('Location permission denied');
      } else if (statusLocation == PermissionStatus.permanentlyDenied) {
        print('Location permission permanently denied');
        // Show dialog that cannot be dismissed until user opens settings
        showOpenSettingsDialog(context, "Location");
      }

    }
    else
    {
      getDeviceRegistrationStatus(deviceIdentifier!);
    }

    // Handle other permissions like storage
    if (statusStorage != PermissionStatus.granted) {
      if (statusStorage == PermissionStatus.denied) {
        print('Storage permission denied');
      } else if (statusStorage == PermissionStatus.permanentlyDenied) {
        print('Storage permission permanently denied');
        // Show dialog that cannot be dismissed until user opens settings
        showOpenSettingsDialog(context, "Storage");
      }
    }
    else
    {
      getDeviceRegistrationStatus(deviceIdentifier!);
    }
  }

  void showOpenSettingsDialog(BuildContext context, String permissionName) {
    showDialog(
      context: context,
      barrierDismissible: false,  // Prevent dismissal by tapping outside
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
              TextButton(
                onPressed: () async {
                  // Open the app settings page
                  await openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> getAppVersionDataApi(BuildContext context) async {
    bool isUpToDate = true;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    const String url = 'https://api.mcd.gov.in/app/request';
    const String token =
        'eyJhbGciOiJIUzI1NiJ9.e30.g2PzdcLXSunm0_ZW-5d9ptZSpeXZi0qsh_sTuTTojRs';

    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    var body = json.encode({
      "module": "version",
      "event": "current",
      "params": {
        "app_type": Platform.isIOS ? "ios" : "android"
      }
    });

    var request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(headers);
    request.body = body;

    try {
      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> responseData = json.decode(responseBody);

        debugPrint('App Version Data Response: $responseData');

        if (responseData['code'] == 2 &&
            responseData['data'] != null &&
            responseData['data'] is List &&
            responseData['data'].isNotEmpty) {
          final Map<String, dynamic> versionInfo = responseData['data'][0];

          String serverVersion = versionInfo['version_number'] ?? '';

          // Get current app version
          PackageInfo packageInfo = await PackageInfo.fromPlatform();
          String currentAppVersion = packageInfo.version;

          debugPrint('Server Version: $serverVersion');
          debugPrint('Current App Version: $currentAppVersion');

          if (serverVersion != currentAppVersion) {
            isUpToDate = false;

            Future.delayed(Duration.zero, () {
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const UpdateDialog(),
                );
              }
            });
          } else {
            debugPrint('App is up to date.');
          }
        } else {
          debugPrint('No valid version data found.');
        }
      } else {
        debugPrint("Failed to fetch version data. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("getAppVersionDataApi Exception: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    return isUpToDate;
  }




  Future<void> getAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String appVersion = packageInfo.version;
      String buildNumber = packageInfo.buildNumber;

      print('App Version: $appVersion');
      appVersionFromDevice = appVersion;
      print('Build Number: $buildNumber');
    } catch (e) {
      print("Error fetching app info: $e");
    }
  }

  Future<String?> getDeviceIdentifierNew() async {
    const iosStorageKey = 'ios_device_unique_id';

    if (Platform.isAndroid) {
      try {
        // ✅ Use ANDROID_ID via flutter_udid (persistent across reinstall)
        String androidUdid = await FlutterUdid.udid;
        print('Android device ID: $androidUdid');
        deviceIdentifier = androidUdid;
        _setDeviceIdSharedPref(); // your own storage method
        return deviceIdentifier;
      } catch (e) {
        print('Error getting Android UDID: $e');
        return null;
      }
    }

    else if (Platform.isIOS) {
      try {
        // ✅ Check secure storage for a UUID
        String? storedUUID = await secureStorage.read(key: iosStorageKey);
        if (storedUUID != null) {
          print('iOS stored UUID: $storedUUID');
          deviceIdentifier = storedUUID;
          _setDeviceIdSharedPref();
          return deviceIdentifier;
        } else {
          // ✅ Generate and store new UUID (persistent in Keychain)
          String newUUID = const Uuid().v4();
          await secureStorage.write(key: iosStorageKey, value: newUUID);
          deviceIdentifier = newUUID;
          _setDeviceIdSharedPref();
          print('Generated and stored iOS UUID: $newUUID');
          return deviceIdentifier;
        }
      } catch (e) {
        print('Error accessing iOS storage: $e');
        return null;
      }
    }

    return null;
  }

  Future<void> _setDeviceIdSharedPref() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    print('deviceIdentifier = $deviceIdentifier');
    await prefs.setString('device_unique_id', deviceIdentifier!);

    if (mounted) {
      setState(() {
        deviceUniqueId = prefs.getString('device_unique_id')!;
      });
    }
    print('device_unique_id = $deviceUniqueId');
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


  Future<void> getDeviceRegistrationStatus(String deviceId) async {
    await Future.delayed(const Duration(seconds: 1)); // Optional delay

    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      // No internet connection
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return NoInternetDialog(
            onRetry: () {
              getDeviceRegistrationStatus(deviceIdentifier!);
            },
          );
        },
      );
      return;
    }

    var parameter = {
      "deviceId": deviceId,
    };

    await apiBaseHelper
        .postAPICall(deviceRegistrationStatusApi, parameter)
        .then((getData) {
      String error = getData['error'].toString();
      String? status = getData['status'].toString();

      print("API Response: $getData");

      if (status == 'TRUE') {
        var employeeXML = getData['employeeXML'];
        if (mounted) {
          setState(() {
            empDeviceData = [EmployeeXML.fromJson(employeeXML)];
            userBmid = empDeviceData[0].empCode.toString();
            empGuid = empDeviceData[0].empGuid;
            empName = empDeviceData[0].empName;
            print("empGuid: ${empDeviceData[0].empGuid}");
            _getPref();
          });
        }
      } else if (error == 'DEVICE NOT REGISTERED.') {
        if (mounted) {
          setState(() {
            showDialog(
              barrierDismissible: false,
              context: context,
              builder: (_) => WillPopScope( onWillPop: () async => false,
                  child: const DeviceRegisterDialog()),
            );
          });
        }
      } else {
        _showNullValueError('getDeviceRegistrationStatus Api: $error $status');
      }
    }, onError: (e) {
      if (mounted) {
        _showNullValueError('getDeviceRegistrationStatus Api onError: ${e.toString()}');
      }
    }).whenComplete(() {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  // Future<void> getDeviceRegistrationStatus(String deviceId) async {
  //   if (!mounted) return;
  //
  //   setState(() {
  //     _isLoading = true;
  //   });
  //
  //   // Optional delay to simulate loading
  //   await Future.delayed(const Duration(seconds: 1));
  //
  //   var connectivityResult = await (Connectivity().checkConnectivity());
  //   if (connectivityResult == ConnectivityResult.none) {
  //     showDialog(
  //       context: context,
  //       builder: (BuildContext context) {
  //         return NoInternetDialog(
  //           onRetry: () {
  //             getDeviceRegistrationStatus(deviceIdentifier!);
  //           },
  //         );
  //       },
  //     );
  //     return;
  //   }
  //
  //   const String url = newBaseUrl;
  //   const String token = 'eyJhbGciOiJIUzI1NiJ9.e30.g2PzdcLXSunm0_ZW-5d9ptZSpeXZi0qsh_sTuTTojRs';
  //
  //   var headers = {
  //     'Content-Type': 'application/json',
  //     'Authorization': 'Bearer $token',
  //   };
  //
  //   var body = json.encode({
  //     "module": "attendance",
  //     "event": "device_status",
  //     "params": {
  //       "device_id": deviceId,
  //     }
  //   });
  //
  //   var request = http.Request('GET', Uri.parse(url));
  //   request.body = body;
  //   request.headers.addAll(headers);
  //
  //   try {
  //     http.StreamedResponse response = await request.send();
  //
  //     if (response.statusCode == 200) {
  //       String responseBody = await response.stream.bytesToString();
  //       final Map<String, dynamic> getData = json.decode(responseBody);
  //
  //       print("API Response: $getData");
  //
  //       String msg = getData['msg']?.toString() ?? '';
  //       String code = getData['code']?.toString() ?? '';
  //
  //       if (code == '2') {
  //         var employeeXML = getData['data'];
  //         if (mounted) {
  //           setState(() {
  //             empDeviceData = [EmployeeXML.fromJson(employeeXML)];
  //             userBmid = empDeviceData[0].emp_bmid.toString();
  //             empName = empDeviceData[0].emp_name;
  //             debugPrint("emp_bmid: ${empDeviceData[0].emp_bmid}");
  //             _getPref();
  //           });
  //         }
  //       } else if (code == '1' && msg == 'No device is registered.') {
  //         if (mounted) {
  //           showDialog(
  //             barrierDismissible: false,
  //             context: context,
  //             builder: (_) => WillPopScope(
  //               onWillPop: () async => false,
  //               child: const DeviceRegisterDialog(),
  //             ),
  //           );
  //         }
  //       } else {
  //         _showNullValueError('getDeviceRegistrationStatus Api: $msg');
  //       }
  //     } else {
  //       _showNullValueError('getDeviceRegistrationStatus Api: HTTP ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     _showNullValueError('getDeviceRegistrationStatus Api Exception: ${e.toString()}');
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   }
  // }


  _getPref() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // First, check if app is updated
    if (!isAppUpdated) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const UpdateDialog(),
      );
      return; // Exit the function if app is not updated
    }

    // First, check permissions explicitly before proceeding
    PermissionStatus cameraStatus = await Permission.camera.status;
    PermissionStatus locationStatus = await Permission.location.status;

    // Log the BMID for debugging
    if (kDebugMode) {
      print("djhb = ${prefs.getString('user_bmid')}");
    }

    if (prefs.getString('user_bmid') != null) {
      setState(() {
        userBmid = prefs.getString('user_bmid')!;
      });
    }

    // Proceed with employee data if BMID is found
    if (prefs.getString('user_bmid') != null) {
      List<dynamic> decodedList = jsonDecode(prefs.getString("employeeData")!);
      empTempData = decodedList.map((item) => EmpData.fromJson(item)).toList();
      print("empTempData=$empTempData");
      print(empTempData.first.empName);
      print(empTempData.first.empDesignation);
      print(empTempData.first.mobile);
      print(empTempData.first.email);
      print(empTempData.first.empCode);
      print(empTempData.first.empId);

      // Ensure permissions are granted before navigating
      if (!cameraStatus.isDenied && !cameraStatus.isPermanentlyDenied &&
          !locationStatus.isDenied && !locationStatus.isPermanentlyDenied) {

        Timer(
          const Duration(seconds: 1),
              () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => LayoutScreen(bmid: userBmid, empData: empTempData)
            ),
          ),
        );
      } else {
        // If permissions are denied, show the permission dialog
        requestPermissions(context);
      }
    } else {
      // Ensure permissions are granted before navigating
      if (!cameraStatus.isDenied && !cameraStatus.isPermanentlyDenied &&
          !locationStatus.isDenied && !locationStatus.isPermanentlyDenied) {

        // Navigate to the login screen if no BMID is found
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(
              isLoggingOut: false,
            ),
          ),
        );
      } else {
        // If permissions are denied, show the permission dialog
        requestPermissions(context);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const SplashScreen(),
    );
  }
}


