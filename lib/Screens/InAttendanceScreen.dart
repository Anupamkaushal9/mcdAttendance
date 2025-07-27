import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:http/http.dart'as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_face_api/flutter_face_api.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:image/image.dart' as img;
import 'package:mcd_attendance/Helpers/Constant.dart';
import 'package:mcd_attendance/Helpers/Responsive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/AppBtn.dart';
import '../Helpers/Session.dart';
import '../Helpers/String.dart';
import '../Model/Employee.dart';
import '../Model/EmployeeHistoryModel.dart';
import '../Utils/fake_location_util.dart';
import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class InAttendanceScreen extends StatefulWidget {
  final List<EmpData>? employee;
  final String inTime;
  final String outTime;
  const InAttendanceScreen({super.key, this.employee, required this.inTime, required this.outTime});

  @override
  State<InAttendanceScreen> createState() => _InAttendanceScreenState();
}

class _InAttendanceScreenState extends State<InAttendanceScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();
  String _locationMessage = '';
  double currentLat = 0.0;
  double currentLong = 0.0;
  bool _isLoading = true;
  bool _isNetworkAvail = true;
  Animation? buttonSqueezeAnimation;
  AnimationController? buttonController;
  double deviceWidth =
      WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width;
  late AnimationController _controller;
  late AnimationController _anController;
  late Animation<double> _animation;
  late Animation<double> _animation1;
  String address = '';
  late AnimationController _scannerAnimationController;
  late Future<void> _initializeControllerFuture;
  bool _isCameraInitialized = false;
  int _remainingTime = 180;
  Timer? _attendanceTimer;
  bool _isInitialized = false;
  bool _isAuthenticating = false;
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  List<int> imageBytes = [];
  File displayImage = File('');
  var faceSdk = FaceSDK.instance;
  String livenessStatus = "Waiting for liveness check...";
  var _status = "nil";
  var similarity = "nil";
  var liveNess = "nil";
  MatchFacesImage? mfImage1;
  MatchFacesImage? mfImage2;
  Uint8List? fetchedImageBytes;
  String error = '';
  bool _isLivelinessInProgress = false;
  String locationStatus = '';
  String base64Image = '';
  Uint8List? image;
  Uint8List? imageDuringLivelinessCheck;
  String inTime = '';
  bool showLoader = false;
  final TextEditingController remarkController = TextEditingController();
  bool _isDisposed = false;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
  GlobalKey<ScaffoldMessengerState>();
  bool hasFaceData = false;

  @override
  void initState() {
    super.initState();
    _scannerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _anController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation1 = CurvedAnimation(
      parent: _anController,
      curve: Curves.easeInOut,
    );

    checkNetwork();

    buttonController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    buttonSqueezeAnimation = Tween(
      begin: deviceWidth * 0.7,
      end: 50.0,
    ).animate(CurvedAnimation(
      parent: buttonController!,
      curve: const Interval(0.0, 0.150),
    ));

    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 50, end: 70).animate(_controller);
    _checkInternetAndInitialize();
  }

  Future<void> _executeWithMountedCheck(
      FutureOr<void> Function() operation, String operationName) async {
    try {
      if (mounted && !_isDisposed) {
        await operation();
      }
    } catch (e) {
      debugPrint('Error in $operationName: $e');
    }
  }

  void _showSafeSnackBar(String message) {
    if (!mounted || _isDisposed) return;

    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
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

  Future<void> _checkInternetAndInitialize() async {
    try {
      if (!mounted || _isDisposed) return;

      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (!mounted || _isDisposed) return;
        await _showSafeDialog(
          NoInternetDialog(
            onRetry: () => (Platform.isAndroid)
                ? FlutterExitApp.exitApp()
                : FlutterExitApp.exitApp(iosForceExit: true),
          ),
        );
        return;
      }

      // ✅ Check version compatibility before doing anything else
      bool isUpToDate = await getAppVersionDataApi(context);
      if (!isUpToDate) {
        debugPrint('App version is outdated. Halting further initialization.');
        return;
      }

      hasFaceData = await getUserFaceData();
      if (!hasFaceData) {
        return;
      }

      await Future.wait([
        _executeWithMountedCheck(getLastAttendance, 'getLastAttendance'),
      ]);

      debugPrint(
          "Current time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}");

      await _executeWithMountedCheck(() async {
        await _getCurrentLocation();

        if (currentLat != 0.0 && currentLong != 0.0) {
          await _executeWithMountedCheck(() async {
            await getDistanceData();
          }, 'getDistanceData');
        }
      }, '_getCurrentLocation');

      await _executeWithMountedCheck(() {
        // Skip mock location check for iOS
        if (!Platform.isIOS) {
          checkForMockLocation(context);
        }
      }, 'checkForMockLocation');
    } catch (e) {
      debugPrint('Error in _checkInternetAndInitialize: $e');
      _showSafeSnackBar('Initialization failed. Please try again.');
    } finally {
      if (mounted && !_isDisposed) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> getAppVersionDataApi(BuildContext context) async {
    bool isUpToDate = true;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    const String url = newBaseUrl;
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

          // String serverVersion = versionInfo['version_number'] ?? '';
          String serverVersion = '1.2.3';
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      Future.delayed(Duration.zero, () {
        if (mounted) {
          // Skip mock location check for iOS
          if (!Platform.isIOS) {
            checkForMockLocation(context);
          }
        }
      });
    }
  }

  Future<void> _clearPreference() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.clear();
  }

  Future<void> _showSafeDialog(Widget dialog) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => dialog,
    );
  }

  getLastAttendance() async {
    print('last attendance api is running');
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "empGuid": empGuid,
    };

    await apiBaseHelper.postAPICall(lastAttendanceApi, parameter).then(
          (getData) {
        String error = getData['error']?.toString() ?? '';
        String status = getData['status']?.toString() ?? '';

        if (status == 'TRUE') {
          String inTime = getData['in_time']?.toString() ?? '';
          String outTime = getData['out_time']?.toString() ?? '';

          if (mounted) {
            setState(() {
              print('In Time: $inTime');
              print('Out Time: $outTime');

              DateTime now = DateTime.now();

              if (inTime.isNotEmpty && outTime.isNotEmpty) {
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
              } else if (inTime.isNotEmpty && outTime.isEmpty) {
                DateTime inDateTime = DateTime.parse(inTime);
                Duration difference = now.difference(inDateTime);

                if (difference.inHours >= 20) {
                  inTiming = '';
                  outTiming = '';
                } else {
                  inTiming = inTime;
                  outTiming = outTime;
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
              if (!isFreshUser) {
                _clearPreference();
                showDialog(
                  context: context,
                  builder: (_) => WillPopScope(
                    onWillPop: () async => false,
                    child: SomethingWentWrongDialog(
                      errorDetails: error,
                    ),
                  ),
                );
              }
            }
          } else if (error.isNotEmpty) {
            debugPrint('Error: $error');
            _showNullValueError("getLastAttendance Api :$error $status");
          }
        }
      },
      onError: (e) {
        if (mounted) {
          _showNullValueError("getLastAttendance Api :$e");
        }
      },
    );
  }

  Future<void> saveInAttendance() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _isAuthenticating = true;
        });
      }

      inTiming = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      var userData = {
        "inLocAddInfo": address,
        "inLatAdd": currentLat.toString(),
        "inLonAdd": currentLong.toString(),
        "attCaptureByGuid": empGuid,
        "orgGuid": "15f5e483-42e2-48ea-ab76-a4e26a20011c",
        "deviceId": deviceUniqueId,
        "inTime": inTiming,
        "empGuid": empGuid,
        "inEmpPic": base64Image,
      };

      var response = await apiBaseHelper.postAPICall(saveInAttendanceApi, userData);
      if (!mounted) return;

      String status = response['status']?.toString() ?? 'FALSE';
      String message = response['message'] ?? 'No message provided';
      String errorMessage = response['error'] ?? 'No message provided';

      if (status == 'TRUE') {
        if (mounted) {
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (context) => WillPopScope(
              onWillPop: () async => false,
              child: SuccessDialog(messageApi: message),
            ),
          );
        }
      } else {
        if (mounted) {
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (context) => WillPopScope(
              onWillPop: () async => false,
              child: FailureDialogNormal(
                messageApi: "$errorMessage $status",
                comingFrom: 'inAttendance',
                onTryAgain: () {
                  Navigator.pop(context);
                  checkLiveliness();
                },
                onCancel: () {
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: FailureDialogNormal(
              messageApi: e.toString(),
              comingFrom: 'inAttendance',
              onTryAgain: () {
                Navigator.pop(context);
                checkLiveliness();
              },
              onCancel: () {
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> saveOutAttendance() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _isAuthenticating = true;
        });
      }

      outTiming = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      var userData = {
        "empGuid": empGuid,
        "deviceId": deviceUniqueId,
        "orgGuid": orgGuid,
        "outEmpPic": base64Image,
        "inTime": inTiming,
        "outTime": outTiming,
        "outLatAdd": currentLat.toString(),
        "outLonAdd": currentLong.toString(),
        "outLocAddInfo": address,
        "attCaptureByGuid": empGuid,
      };

      final response = await apiBaseHelper.postAPICall(saveOutAttendanceApi, userData);
      if (!mounted) return;

      String status = response['status'] ?? 'FALSE';
      String message = response['message'] ?? 'Unknown Error';
      String errorMessage = response['error'] ?? 'No message provided';

      if (status == 'TRUE') {
        if (mounted) {
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (context) => WillPopScope(
              onWillPop: () async => false,
              child: SuccessDialog(messageApi: message),
            ),
          );
        }
      } else {
        if (mounted) {
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (context) => WillPopScope(
              onWillPop: () async => false,
              child: FailureDialogNormal(
                messageApi: "$errorMessage $status",
                comingFrom: 'inAttendance',
                onTryAgain: () {
                  Navigator.pop(context);
                  checkLiveliness();
                },
                onCancel: () {
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: FailureDialogNormal(
              comingFrom: 'inAttendance',
              messageApi: e.toString(),
              onTryAgain: () {
                Navigator.pop(context);
                checkLiveliness();
              },
              onCancel: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> getDistanceData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final parameter = {
      "inLatAdd": currentLat,
      "inLonAdd": currentLong,
      "orgUnitGuid": orgUnitBasicGuid,
    };

    try {
      final responseData = await apiBaseHelper.postAPICall(getDistanceApi, parameter);

      if (responseData is Map<String, dynamic>) {
        final String status = responseData['status']?.toString() ?? '';
        final String distance = responseData['distance']?.toString() ?? '';

        print("API Response: $responseData");

        if (status == 'TRUE') {
          if (mounted) {
            setState(() {
              locationStatus = (distance == 'TRUE') ? "In office" : "Out of office";
            });
          }

          if (distance != 'TRUE') {
            showDialog(
              barrierDismissible: false,
              context: context,
              builder: (BuildContext context) {
                return WillPopScope(
                  onWillPop: () async => false,
                  child: const OutOfOfficeDialog(),
                );
              },
            );
          }
        } else {
          _showNullValueError("getDistance Api :Failed to fetch distance: $status");
        }
      } else {
        throw Exception("getDistance Api : Invalid response format from API.");
      }
    } catch (e) {
      print("Error in getDistanceData: $e");
      _showNullValueError("getDistance Api :Error occurred: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _attendanceTimer?.cancel();
    _controller.dispose();
    _anController.dispose();
    buttonController?.dispose();
    _scannerAnimationController.dispose();
    super.dispose();
  }

  Future<bool> initialize({int retryCount = 2}) async {
    bool returndata = true;
    for (int attempt = 1; attempt <= retryCount; attempt++) {
      try {
        debugPrint("Initialization attempt $attempt");

        if (attempt >= 1) {
          await _cleanupFaceSDK();
          await Future.delayed(Duration(seconds: attempt));
        }
        var license = await loadAssetIfExists("assets/regula.license");
        InitConfig? config;
        if (license != null) {
          config = InitConfig(license);
          debugPrint('config $config');
        }
        var response = await faceSdk.initialize(config: config);
        debugPrint("license initialization response $response");
        String data = response.toString();
        String isTrue = data.split(',')[0].replaceFirst('(', '');

        if (isTrue == 'true') {
          returndata = true;
          checkLiveliness();
        } else {
          returndata = false;
        }
      } catch (e) {
        debugPrint("error license $e");
      }
      debugPrint('return data $returndata');
      return returndata;
    }
    return false;
  }

  _cleanupFaceSDK() async {
    try {
      faceSdk.deinitialize();
      debugPrint("FaceSDK successfully deinitialized");
    } catch (e) {
      debugPrint("Error deinitializing FaceSDK: $e");
    }
  }

  Future<ByteData?> loadAssetIfExists(String path) async {
    try {
      return await rootBundle.load(path);
    } catch (_) {
      return null;
    }
  }

  setImage(Uint8List bytes, ImageType type, int number) async {
    var mfImage = MatchFacesImage(bytes, type);
    if (number == 1) {
      mfImage1 = mfImage;
      liveStatus = "nil";
    }
    if (number == 2) {
      mfImage2 = mfImage;
    }
  }

  Future<void> getPlacemarks(double lat, double long) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        if (mounted) {
          setState(() {
            address = "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            address = "No address available for the given coordinates.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          address = "Failed to get address: $e";
        });
      }
    }
  }

  set liveStatus(String val) {
    debugPrint('value is $val');
    liveNess = val;
  }

  set similarityStatus(String val) {
    similarity = val;
    debugPrint("similarity $similarity");
  }

  void matchFaces() async {
    FocusScope.of(context).unfocus();
    debugPrint("mfImage1 $mfImage1  mfImage2 $mfImage2");
    var mfImage3 = MatchFacesImage(fetchedImageBytes!, ImageType.LIVE);
    try {
      if (mfImage1 == null || fetchedImageBytes == null) {
        _status = "All images are required!";
        return;
      }

      if (mounted) {
        setState(() {
          _isAuthenticating = true;
        });
      }

      // Compress the fetched image and store it in base64Image
      final compressedFetchedImage = await compressImage(fetchedImageBytes!);
      base64Image = base64Encode(compressedFetchedImage);  // <-- Store as base64
      debugPrint('base64Image size: ${base64Image.length / 1024} KB');  // Size in KB

      // Print original and compressed sizes for comparison
      debugPrint('Original image size: ${fetchedImageBytes!.lengthInBytes / 1024} KB');
      debugPrint('Compressed binary size: ${compressedFetchedImage.lengthInBytes / 1024} KB');

      var request1 = MatchFacesRequest([mfImage1!, mfImage3!]);
      var response1 = await faceSdk.matchFaces(request1);
      debugPrint("Liveness vs Fetched face match response $response1");

      var split1 = await faceSdk.splitComparedFaces(response1.results, 0.75);
      var match1 = split1.matchedFaces;
      debugPrint("Liveness vs Fetched face match data $match1");

      bool livenessMatchSuccess = false;
      if (match1.isNotEmpty && match1[0].similarity >= 0.75) {
        livenessMatchSuccess = true;
      }

      if (livenessMatchSuccess) {
        if (inTiming.isNotEmpty) {
          await saveOutAttendance();
          await getLastAttendance();
        } else {
          await saveInAttendance();
          await getLastAttendance();
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => WillPopScope(
              onWillPop: () async => false,
              child: FailureDialog(
                comingFrom: 'inAttendance',
                onTryAgain: () {
                  Navigator.pop(context);
                  checkLiveliness();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error matching faces: $e");
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => WillPopScope(
            onWillPop: () async => false,
            child: FailureDialog(
              comingFrom: 'inAttendance',
              onTryAgain: () {
                Navigator.pop(context);
                checkLiveliness();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted && !_isAuthenticating) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  setImageTwo() async {
    Uint8List imageBytes;
    try {
      if (fetchedImageBytes != null && fetchedImageBytes!.isNotEmpty) {
        var mfImage = MatchFacesImage(fetchedImageBytes!, ImageType.LIVE);
        if (mounted) {
          setState(() {
            mfImage2 = mfImage;
          });
        }
      } else {
        debugPrint("Fetched image is empty or null.");
      }
    } catch (e) {
      debugPrint('image set error $e');
    }
  }

  Future<Uint8List> compressImage(Uint8List imageBytes, {
    int targetWidth = 249,
    int targetHeight = 375,
    int quality = 50,
  }) async {
    // Decode image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    // Resize directly to target size
    image = img.copyResize(
      image,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    // Compress to JPEG
    Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));

    // Log for confirmation
    double sizeKB = compressedBytes.lengthInBytes / 1024;
    debugPrint('Compressed directly to $targetWidth x $targetHeight @ quality $quality');
    debugPrint('Final size: ${sizeKB.toStringAsFixed(2)} KB');

    return compressedBytes;
  }




  Future<void> checkLiveliness() async {
    if (_isLivelinessInProgress) return;

    try {
      _isLivelinessInProgress = true;

      var result = await faceSdk.startLiveness(
        config: LivenessConfig(
          copyright: false,
          livenessType: LivenessType.ACTIVE,
          torchButtonEnabled: true,
          skipStep: [
            LivenessSkipStep.ONBOARDING_STEP,
            LivenessSkipStep.SUCCESS_STEP
          ],
        ),
        notificationCompletion: (notification) {
          if (!mounted || !_isLivelinessInProgress) return;
          setState(() {
            livenessStatus = "Liveness Status: ${notification.status}";
          });
        },
      );

      if (result.image == null) {
        debugPrint("Result image is ${result.image}");
        if (mounted) {
          setState(() {
            livenessStatus = "Liveness check failed!";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            imageDuringLivelinessCheck = result.image;
            livenessStatus = "Liveness status: ${result.liveness.name}";
            debugPrint(livenessStatus);
          });
        }
        if (result.liveness.name == 'PASSED') {
          setState(() {
            _isAuthenticating = true;
          });
          setImage(imageDuringLivelinessCheck!, ImageType.LIVE, 1);
          base64Image = base64Encode(imageDuringLivelinessCheck!);
          matchFaces();
        }
      }
    } catch (e) {
      debugPrint('Error during liveness check: $e');
      if (mounted) {
        setState(() {
          livenessStatus = "Error during liveness check.";
        });
      }
    } finally {
      _isLivelinessInProgress = false;
    }
  }

  void exitLivelinessCheck() {
    if (_isLivelinessInProgress) {
      debugPrint('Cancelling liveness check or face match...');
      faceSdk.stopLiveness();
      faceSdk.stopFaceCapture();
      _isLivelinessInProgress = false;
    }

    if (mounted) {
      setState(() {
        currentLat = 0.0;
        currentLong = 0.0;
        address = '';
      });
      _showSafeDialog(const TimeOutDialog());
    }
  }

  startLiveMatching() async {
    if (!await initialize()) return;
    if (mounted) {
      setState(() {
        _status = "Ready";
      });
    }
  }

  Future<void> requestPermissions(BuildContext context) async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      Permission.photos
    ].request();

    PermissionStatus? statusCamera = statuses[Permission.camera];
    PermissionStatus? statusStorage = statuses[Permission.storage];

    if (statusCamera != PermissionStatus.granted) {
      if (statusCamera == PermissionStatus.denied) {
        print('Camera permission denied');
      } else if (statusCamera == PermissionStatus.permanentlyDenied) {
        print('Camera permission permanently denied');
        showOpenSettingsDialog(context, "Camera");
      }
    }

    if (statusStorage != PermissionStatus.granted) {
      if (statusStorage == PermissionStatus.denied) {
        print('Storage permission denied');
      } else if (statusStorage == PermissionStatus.permanentlyDenied) {
        print('Storage permission permanently denied');
        showOpenSettingsDialog(context, "Storage");
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationMessage = '';
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable Location.")),
        );
        _showSafeSnackBar("Please enable Location.");
        showOpenSettingsDialog(context, "Location");
        Navigator.pop(context);
      } else {
        Map<Permission, PermissionStatus> status = await [
          Permission.location,
        ].request();

        if (status[Permission.location]!.isGranted) {
          Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.best);

          if(!Platform.isIOS){
            if (position.isMocked) {
              showMockLocationDialog(context);
            }
          }

          if (mounted) {
            setState(() {
              _locationMessage =
              'Latitude: ${position.latitude}, Longitude: ${position.longitude}';
              currentLat = position.latitude;
              currentLong = position.longitude;
              _isLoading = true;
            });
          }

          try {
            List<Placemark> placemarks = await placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            ).timeout(const Duration(seconds: 5), onTimeout: () {
              throw Exception('Geocoding request timed out');
            });

            if (placemarks.isNotEmpty) {
              Placemark place = placemarks[0];
              address = "${place.name}, ${place.locality}, ${place.country}";
              setState(() {
                _locationMessage = address;
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _locationMessage = 'Failed to get address: $e';
                _isLoading = false;
              });
            }
            _showSafeDialog(LocationExceptionDialog(errorDetails: e.toString()));
            _showSafeSnackBar('Failed to fetch address: $e');
          }

          _attendanceTimer =
              Timer.periodic(const Duration(seconds: 1), (timer) {
                if (_remainingTime > 0) {
                  if (mounted) {
                    setState(() {
                      _remainingTime--;
                    });
                  }
                } else {
                  timer.cancel();
                  exitLivelinessCheck();

                  if (mounted) {
                    setState(() {
                      currentLat = 0.0;
                      currentLong = 0.0;
                      address = '';
                    });
                  }
                }
              });
        } else {
          _showSafeSnackBar("Location permission is required.");
          Navigator.pop(context);
          Timer(const Duration(seconds: 2), () => openAppSettings());
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationMessage = 'Failed to get location: $e';
          _isLoading = false;
        });
      }
    }
  }

  checkNetwork() async {
    _isNetworkAvail = await isNetworkAvailable();
    if (_isNetworkAvail) {
      if (mounted) {
        setState(() {
          _isNetworkAvail = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  Future<bool> getUserFaceData() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? base64Image = prefs
          .getString('user_face_data')
          ?.replaceFirst('data:image/jpeg;base64,', '');

      fetchedImageBytes = base64Decode(base64Image??'');
      return true;
    } catch (e) {
      if (mounted) {
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Error'),
                content: Text('Failed to load face data: ${e.toString()}'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            });
      }
      return false;
    }
  }

  void showOpenSettingsDialog(BuildContext context, String permissionName) {
    showDialog(
      context: context,
      barrierDismissible: false,
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

  @override
  Widget build(BuildContext context) {
    return (_isAuthenticating)
        ? Scaffold(
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: LottieBuilder.asset(
            'assets/animations/face_authenticating.json',
            repeat: true,
          ),
        ),
      ),
    )
        : (hasFaceData)
        ? Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: !_isLoading?true:false,
      appBar: const GlassAppBar(title: 'MCD PRO', isLayoutScreen: false),
      resizeToAvoidBottomInset: true,
      body: _isNetworkAvail
          ? !_isLoading
          ? SingleChildScrollView(
        child: Padding(
          padding:  EdgeInsets.only(left: 8.0,right: 8.0,bottom: 8.0,top: kToolbarHeight+5.h + MediaQuery.of(context).padding.top),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 100,
                  backgroundImage:
                  MemoryImage(fetchedImageBytes!),
                ),
              ),
              SizedBox(height: 10.h),
              Center(
                child: Text(
                  locationStatus,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (locationStatus ==
                          "Out of office")
                          ? Colors.red
                          : Colors.green,
                      fontSize: 20.sp),
                ),
              ),
              SizedBox(height: 20.h),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Address : $address',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15.0.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8.0),
                child: Text(
                  'Latitude : ${double.parse(currentLat.toStringAsFixed(6))}, Longitude : ${double.parse(currentLong.toStringAsFixed(6))}',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Column(
                children: [
                  SizedBox( // Added fixed height container
                    //height: 60, // Adjust this value as needed
                    child: TextField(
                      controller: remarkController,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      maxLines: null,
                      decoration: const InputDecoration( // Removed 'expands: true'
                        border: OutlineInputBorder(),
                        hintText: 'Type your message here',
                      ),
                    ),
                  ),
                ],
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Complete your attendance in: ${_formatDuration(_remainingTime)}',
                    style: TextStyle(
                      fontSize: 18.0.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: (currentLat != 0.0 && currentLat != null)
                      ? () async {
                    bool isGpsEnabled = await Geolocator.isLocationServiceEnabled();
                    if (!isGpsEnabled) {
                      _showSafeSnackBar('Please turn on GPS to proceed');
                      return;
                    }

                    setState(() {
                      showLoader = true;
                    });

                    await initialize();

                    if (mounted) {
                      setState(() {
                        Future.delayed(const Duration(
                            seconds: 3))
                            .then((_) {
                          showLoader = false;
                        });
                      });
                    }
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff111184),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: showLoader
                      ? Center(
                    child: SizedBox(
                      height: 20.h,
                      width: 20.w,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  )
                      : (currentLat != 0.0 && currentLat != null)
                      ? const Text(
                    "Proceed",
                    style: TextStyle(color: Colors.white),
                  )
                      : const Text(
                    "Gps disabled or location permission denied ",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : SizedBox(
        height: MediaQuery.of(context).size.height / 1.3,
        child: Center(
          child: LottieBuilder.asset(
            'assets/animations/loading_animation.json',
            height: 50.h,
            width: 50.w,
          ),
        ),
      )
          : noInternet(context),
    )
        : const Scaffold(
      body: SizedBox(),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _playAnimation() async {
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
            title: 'Try Again',
            btnAnim: buttonSqueezeAnimation,
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