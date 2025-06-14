import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
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
import 'package:mcd_attendance/Helpers/Responsive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/AppBtn.dart';
import '../Helpers/Session.dart';
import '../Helpers/String.dart';
import '../Model/Employee.dart';
import '../Model/EmployeeHistoryModel.dart';
import '../Utils/fake_location_util.dart';
import 'dart:math' as math;

import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class InAttendanceScreen extends StatefulWidget {
  final List<EmpHistoryData>? empHistoryData;
  final List<EmpData>? employee;
  const InAttendanceScreen({super.key, this.empHistoryData, this.employee});

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
  int _remainingTime = 180; // 2 minutes for attendance
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
  Uint8List? fetchedImageBytes; // Fetched image from API or SharedPreferences
  String error = '';
  bool _isLivelinessInProgress =
      false; // Flag to track if liveness or face matching is in progress
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

  livelinessCheck() async {
    await checkLiveliness();
  }

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

      // 1. Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (!mounted || _isDisposed) return;
        await _showSafeDialog(
          NoInternetDialog(
              onRetry: () => (Platform.isAndroid)
                  ? FlutterExitApp.exitApp()
                  : FlutterExitApp.exitApp(iosForceExit: true)),
        );
        return;
      }

      // 2. Initialize critical components in parallel where possible
      hasFaceData = await getUserFaceData();
      if (!hasFaceData) {
        return;
      }
      await Future.wait([
        _executeWithMountedCheck(getLastAttendance, 'getLastAttendance'),
      ]);

      debugPrint(
          "Current time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}");

      // 3. Get location and process sequentially
      await _executeWithMountedCheck(() async {
        await _getCurrentLocation();

        // Ensure we have valid coordinates before getting distance
        if (currentLat != 0.0 && currentLong != 0.0) {
          await _executeWithMountedCheck(() async {
            await getDistanceData();
          }, 'getDistanceData');
        }
      }, '_getCurrentLocation');

      // 4. Run safety checks
      await _executeWithMountedCheck(() {
        checkForMockLocation(context);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Check if the widget is still mounted before calling checkForMockLocation
      if (mounted) {
        // Use a delayed callback to ensure context is valid
        Future.delayed(Duration.zero, () {
          if (mounted) {
            checkForMockLocation(context); // Now it's safe to use context
          }
        });
      }
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
                // ✅ Both inTime and outTime exist
                DateTime inDateTime = DateTime.parse(inTime);

                if (inDateTime.year != now.year ||
                    inDateTime.month != now.month ||
                    inDateTime.day != now.day) {
                  // Different day → clear both
                  inTiming = '';
                  outTiming = '';
                } else {
                  // Same day → keep them
                  inTiming = inTime;
                  outTiming = outTime;
                }
              } else if (inTime.isNotEmpty && outTime.isEmpty) {
                // ✅ inTime exists, outTime missing
                DateTime inDateTime = DateTime.parse(inTime);
                Duration difference = now.difference(inDateTime);

                if (difference.inHours >= 20) {
                  // More than 20 hours passed → clear both
                  inTiming = '';
                  outTiming = '';
                } else {
                  // Less than 20 hours → keep inTime, outTime stays empty
                  inTiming = inTime;
                  outTiming = outTime;
                }
              } else {
                // ❌ inTime is empty → clear both
                inTiming = '';
                outTiming = '';
              }

              _isLoading = false;
            });
          }
        } else {
          // ❌ NO RECORD FOUND or some error
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
    setState(() {
      _isLoading = true;
    });

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

    try {
      var response =
          await apiBaseHelper.postAPICall(saveInAttendanceApi, userData);
      if (!mounted) return;

      if (response is String) {
        response = json.decode(response);
      }

      String status = response['status'].toString();
      String message = response['message'] ?? 'No message provided';
      String errorMessage = response['error'] ?? 'No message provided';
      print("message from api = $message");
      if (status == 'TRUE') {
        BuildContext dialogContext;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (BuildContext newContext) {
              dialogContext = newContext;
              return WillPopScope(
                onWillPop: () async => false,
                child: SuccessDialog(
                  messageApi: message,
                ),
              );
            },
          );
        });

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _showSafeSnackBar(message);
            }
          });
        }
      } else {
        // Failure dialog
        BuildContext dialogContext;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (BuildContext newContext) {
              dialogContext = newContext;
              return WillPopScope(
                onWillPop: () async => false,
                child: FailureDialogNormal(
                  messageApi: "$errorMessage $status",
                  onTryAgain: () {
                    getLastAttendance();
                    checkLiveliness();
                  },
                  onCancel: () {
                    getLastAttendance();
                    Navigator.pop(dialogContext);
                  },
                ),
              );
            },
          );
        });

        setState(() {
          _isLoading = false;
        });

        String error = response['error'] ?? 'Unknown error occurred';
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _showSafeSnackBar("Failed to save attendance: $error");
            }
          });
        }
      }
    } catch (e) {
      // Catch block
      BuildContext dialogContext;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (BuildContext newContext) {
            dialogContext = newContext;
            return WillPopScope(
              onWillPop: () async => false,
              child: FailureDialogNormal(
                messageApi: e.toString(),
                onTryAgain: () {
                  getLastAttendance();
                  Navigator.pop(dialogContext);
                },
                onCancel: () {
                  getLastAttendance();
                  Navigator.pop(dialogContext);
                },
              ),
            );
          },
        );
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _showSafeSnackBar("Error occurred: $e");
          }
        });
      }
    }
  }

  Future<void> saveOutAttendance() async {
    setState(() {
      _isLoading = true;
    });

    outTiming = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    var userData = {
      "empGuid": empGuid,
      "deviceId": deviceUniqueId,
      "orgGuid": orgGuid,
      "outEmpPic": base64Image,
      "inTime": widget.empHistoryData![0].inTime,
      "outTime": outTiming,
      "outLatAdd": currentLat.toString(),
      "outLonAdd": currentLong.toString(),
      "outLocAddInfo": address,
      "attCaptureByGuid": empGuid,
    };

    try {
      final response =
          await apiBaseHelper.postAPICall(saveOutAttendanceApi, userData);
      if (!mounted) return;

      String status = response['status'] ?? 'FALSE';
      String message = response['message'] ?? 'Unknown Error';
      String errorMessage = response['error'] ?? 'No message provided';

      if (status == 'TRUE') {
        BuildContext dialogContext;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (BuildContext newContext) {
              dialogContext = newContext;
              return WillPopScope(
                onWillPop: () async => false,
                child: SuccessDialog(
                  messageApi: message,
                ),
              );
            },
          );
        });

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _showSafeSnackBar(message);
            }
          });
        }
      } else {
        BuildContext dialogContext;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            barrierDismissible: false,
            context: context,
            builder: (BuildContext newContext) {
              dialogContext = newContext;
              return WillPopScope(
                onWillPop: () async => false,
                child: FailureDialogNormal(
                  messageApi: "$errorMessage $status",
                  onTryAgain: () {
                    getLastAttendance();
                    checkLiveliness();
                  },
                  onCancel: () {
                    getLastAttendance();
                    Navigator.pop(dialogContext);
                  },
                ),
              );
            },
          );
        });

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _showSafeSnackBar('Failed to save out attendance: $message');
            }
          });
        }
      }
    } catch (e) {
      BuildContext dialogContext;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (BuildContext newContext) {
            dialogContext = newContext;
            return WillPopScope(
              onWillPop: () async => false,
              child: FailureDialogNormal(
                messageApi: e.toString(),
                onTryAgain: () {
                  getLastAttendance();
                  checkLiveliness();
                },
                onCancel: () {
                  getLastAttendance();
                  Navigator.pop(dialogContext);
                },
              ),
            );
          },
        );
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _showSafeSnackBar('An error occurred: $e');
          }
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
      final responseData =
          await apiBaseHelper.postAPICall(getDistanceApi, parameter);

      if (responseData is Map<String, dynamic>) {
        final String status = responseData['status']?.toString() ?? '';
        final String distance = responseData['distance']?.toString() ?? '';

        print("API Response: $responseData");

        if (status == 'TRUE') {
          if (mounted) {
            setState(() {
              locationStatus =
                  (distance == 'TRUE') ? "In office" : "Out of office";
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
          _showNullValueError(
              "getDistance Api :Failed to fetch distance: $status");
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

  String formatDateTime(DateTime dateTime) {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return dateFormat.format(dateTime);
  }

  Future<bool> initialize({int retryCount = 2}) async {
    bool returndata = true;
    for (int attempt = 1; attempt <= retryCount; attempt++) {
      try {
        debugPrint("Initialization attempt $attempt");

        // Cleanup before reinitialization
        if (attempt >= 1) {
          await _cleanupFaceSDK();
          await Future.delayed(
              Duration(seconds: attempt)); // Exponential backoff
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
          livelinessCheck();
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
      // matchFaces();
    }
  }

  Future<void> getPlacemarks(double lat, double long) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        if (mounted) {
          setState(() {
            address =
                "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
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

  // Compare the captured image with the stored image
  // void matchFaces() async {
  //   debugPrint("mfImage1 $mfImage1  mfImage2 $mfImage2");
  //   var mfImage3 = MatchFacesImage(fetchedImageBytes!, ImageType.LIVE);
  //   try {
  //     // Check if both images (livenessImage and captureResultImage) are available
  //     if (mfImage1 == null || mfImage2 == null || fetchedImageBytes == null) {
  //       _status = "All images are required!";
  //       return;
  //     }
  //
  //     _status = "Processing status";
  //     if (mounted) {
  //       setState(() {
  //         _isAuthenticating = true; // Start authentication process
  //       });
  //     }
  //
  //     // Perform face matching for livenessImage vs fetchedImageBytes
  //     var request1 = MatchFacesRequest([mfImage1!, mfImage3!]);
  //     var response1 = await faceSdk.matchFaces(request1);
  //     debugPrint("Liveness vs Fetched face match response $response1");
  //
  //     var split1 = await faceSdk.splitComparedFaces(response1.results, 0.75);
  //     var match1 = split1.matchedFaces;
  //     debugPrint("Liveness vs Fetched face match data $match1");
  //
  //     similarity = "failed";
  //     bool livenessMatchSuccess = false;
  //     if (match1.isNotEmpty) {
  //       similarity = "${(match1[0].similarity * 100).toStringAsFixed(2)}%";
  //       debugPrint("Liveness match similarity: $similarity");
  //
  //       if (match1[0].similarity >= 0.75) {
  //         livenessMatchSuccess = true;
  //       }
  //     }
  //
  //     // Perform face matching for captureResult.image vs fetchedImageBytes
  //     var request2 = MatchFacesRequest([mfImage2!, mfImage3!]);
  //     var response2 = await faceSdk.matchFaces(request2);
  //     debugPrint("Capture vs Fetched face match response $response2");
  //
  //     var split2 = await faceSdk.splitComparedFaces(response2.results, 0.75);
  //     var match2 = split2.matchedFaces;
  //     debugPrint("Capture vs Fetched face match data $match2");
  //
  //     bool captureMatchSuccess = false;
  //     if (match2.isNotEmpty) {
  //       similarity = "${(match2[0].similarity * 100).toStringAsFixed(2)}%";
  //       debugPrint("Capture match similarity: $similarity");
  //
  //       if (match2[0].similarity >= 0.75) {
  //         captureMatchSuccess = true;
  //       }
  //     }
  //
  //     // If both matches pass, proceed with success logic
  //     if (livenessMatchSuccess && captureMatchSuccess) {
  //       // Handle attendance saving based on empHistoryData status
  //       if(mounted)
  //       {
  //         setState(() {
  //           _isAuthenticating = false; // Reset authentication flag
  //           if (widget.empHistoryData != null && widget.empHistoryData!.isNotEmpty) {
  //             if (inTiming.isNotEmpty) {
  //               // If empHistoryData is not empty and inTime exists, save out attendance
  //               saveOutAttendance();
  //             } else {
  //               // If empHistoryData is not empty but inTime doesn't exist, save in attendance
  //               saveInAttendance();
  //             }
  //           } else {
  //             // If empHistoryData is empty (first attendance), save in attendance
  //             saveInAttendance();
  //           }
  //         });
  //       }
  //
  //     } else {
  //       // If either match fails, show failure dialog
  //       if (mounted) {
  //         setState(() {
  //           showDialog(
  //             context: context,
  //             barrierDismissible:false ,
  //             builder: (_) => WillPopScope( onWillPop: () async => false,
  //               child: FailureDialog(
  //                 onTryAgain: () {
  //                   // Navigator.pop(context);
  //                   checkLiveliness();
  //                 },
  //               ),
  //             ),
  //           );
  //         });
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint("Error matching faces: $e");
  //
  //     // Show the failure dialog on error
  //     if (mounted) {
  //       setState(() {
  //         showDialog(
  //           context: context,
  //           builder: (_) => FailureDialog(
  //             onTryAgain: () {
  //               checkLiveliness();
  //               Navigator.pop(context);
  //             },
  //           ),
  //         );
  //       });
  //     }
  //   } finally {
  //     // Ensure isAuthenticating is reset after the process
  //     if (mounted) {
  //       setState(() {
  //         _isAuthenticating = false; // Reset authentication flag
  //       });
  //     }
  //   }
  // }

  // Update the setImageTwo method to compare the live image with the fetched image
  void matchFaces() async {
    FocusScope.of(context).unfocus();
    debugPrint("mfImage1 $mfImage1  mfImage2 $mfImage2");
    var mfImage3 = MatchFacesImage(fetchedImageBytes!, ImageType.LIVE);
    try {
      // Check if both images (livenessImage and captureResultImage) are available
      if (mfImage1 == null || fetchedImageBytes == null) {
        _status = "All images are required!";
        return;
      }

      _status = "Processing status";
      if (mounted) {
        setState(() {
          _isAuthenticating = true; // Start authentication process
        });
      }

      // Perform face matching for livenessImage vs fetchedImageBytes
      var request1 = MatchFacesRequest([mfImage1!, mfImage3!]);
      var response1 = await faceSdk.matchFaces(request1);
      debugPrint("Liveness vs Fetched face match response $response1");

      var split1 = await faceSdk.splitComparedFaces(response1.results, 0.75);
      var match1 = split1.matchedFaces;
      debugPrint("Liveness vs Fetched face match data $match1");

      similarity = "failed";
      bool livenessMatchSuccess = false;
      if (match1.isNotEmpty) {
        similarity = "${(match1[0].similarity * 100).toStringAsFixed(2)}%";
        debugPrint("Liveness match similarity: $similarity");

        if (match1[0].similarity >= 0.75) {
          livenessMatchSuccess = true;
        }
      }

      // If both matches pass, proceed with success logic
      if (livenessMatchSuccess) {
        // Handle attendance saving based on empHistoryData status
        if (mounted) {
          setState(() {
            _isAuthenticating = false; // Reset authentication flag
            if (widget.empHistoryData != null &&
                widget.empHistoryData!.isNotEmpty) {
              if (inTiming.isNotEmpty) {
                // If empHistoryData is not empty and inTime exists, save out attendance
                saveOutAttendance();
                getLastAttendance();
              } else {
                // If empHistoryData is not empty but inTime doesn't exist, save in attendance
                saveInAttendance();
                getLastAttendance();
              }
            } else {
              // If empHistoryData is empty (first attendance), save in attendance
              saveInAttendance();
              getLastAttendance();
            }
          });
        }
      } else {
        // If either match fails, show failure dialog
        if (mounted) {
          setState(() {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => WillPopScope(
                onWillPop: () async => false,
                child: FailureDialog(
                  onTryAgain: () {
                    // Navigator.pop(context);
                    checkLiveliness();
                  },
                ),
              ),
            );
          });
        }
      }
    } catch (e) {
      debugPrint("Error matching faces: $e");

      // Show the failure dialog on error
      if (mounted) {
        setState(() {
          showDialog(
            context: context,
            builder: (_) => FailureDialog(
              onTryAgain: () {
                checkLiveliness();
                Navigator.pop(context);
              },
            ),
          );
        });
      }
    } finally {
      // Ensure isAuthenticating is reset after the process
      if (mounted) {
        setState(() {
          _isAuthenticating = false; // Reset authentication flag
        });
      }
    }
  }

  setImageTwo() async {
    Uint8List imageBytes;
    try {
      // Assuming this is the API or SharedPreferences fetched image
      if (fetchedImageBytes != null && fetchedImageBytes!.isNotEmpty) {
        // Setting fetched image as mfImage2
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

  // Perform liveness check
  // Future<void> checkLiveliness() async {
  //   try {
  //     // Mark the liveness process as in progress
  //     _isLivelinessInProgress = true;
  //
  //     var result = await faceSdk.startLiveness(
  //       config: LivenessConfig(
  //         copyright: false,
  //         livenessType: LivenessType.ACTIVE,
  //         torchButtonEnabled: true,
  //         skipStep: [
  //           LivenessSkipStep.ONBOARDING_STEP,
  //           LivenessSkipStep.SUCCESS_STEP
  //         ],
  //       ),
  //       notificationCompletion: (notification) {
  //         if (!mounted || !_isLivelinessInProgress) return;
  //         if (mounted) {
  //           setState(() {
  //             livenessStatus = "Liveness Status: ${notification.status}";
  //           });
  //         }
  //       },
  //     );
  //
  //     if (result.image == null) {
  //       debugPrint("Result image is ${result.image}");
  //       if (mounted) {
  //         setState(() {
  //           livenessStatus = "Liveness check failed!";
  //         });
  //       }
  //     } else {
  //       if (mounted) {
  //         setState(() {
  //           imageDuringLivelinessCheck =  result.image;
  //           livenessStatus = "Liveness Passed: ${result.liveness.name}";
  //         });
  //       }
  //       await captureAndAuthenticate(); // Proceed with face authentication
  //     }
  //   } catch (e) {
  //     debugPrint('Error during liveness check: $e');
  //     if (mounted) {
  //       setState(() {
  //         livenessStatus = "Error during liveness check.";
  //       });
  //     }
  //   }
  // }

  Future<void> checkLiveliness() async {
    try {
      // Mark the liveness process as in progress
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
          if (mounted) {
            setState(() {
              livenessStatus = "Liveness Status: ${notification.status}";
            });
          }
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
            livenessStatus = "Liveness Passed: ${result.liveness.name}";
          });
        }
        //await captureAndAuthenticate(); // Proceed with face authentication
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
    }
  }

  void exitLivelinessCheck() {
    // If liveness check or similarity check is still in progress, cancel them
    if (_isLivelinessInProgress) {
      debugPrint('Cancelling liveness check or face match...');
      faceSdk
          .stopLiveness(); // Assuming this is a method to stop the liveness check
      faceSdk.stopFaceCapture();
      _isLivelinessInProgress = false;
    }

    // Clear any data, reset states, and navigate back
    if (mounted) {
      setState(() {
        currentLat = 0.0;
        currentLong = 0.0;
        address = '';
      });
      _showSafeDialog(const TimeOutDialog());
      // Go back to the previous screen
    }
  }

  // Future<void> captureAndAuthenticate() async {
  //   try {
  //     var captureResult = await faceSdk.startFaceCapture(
  //       config: FaceCaptureConfig(
  //           cameraPositionAndroid: 1, cameraPositionIOS: CameraPosition.FRONT),
  //     );
  //
  //     if (captureResult.image != null) {
  //       base64Image = base64Encode(captureResult.image!.image);
  //       image = captureResult.image!.image;
  //       setImage(captureResult.image!.image, ImageType.LIVE, 1);
  //       setImage(imageDuringLivelinessCheck!, ImageType.LIVE, 2);
  //       matchFaces();
  //     } else {
  //       print("capture image is null");
  //     }
  //   } catch (e) {
  //     debugPrint('Error during face capture or authentication: $e');
  //     if (mounted) {
  //       setState(() {
  //         livenessStatus = "Error during face capture or authentication.";
  //       });
  //     }
  //   }
  // }

  startLiveMatching() async {
    if (!await initialize()) return;
    if (mounted) {
      setState(() {
        _status = "Ready";
      });
    }
  }

  // Function to request permissions
  Future<void> requestPermissions(BuildContext context) async {
    // Request permissions for camera, storage, and photos
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      Permission.photos
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
        // Show dialog that cannot be dismissed until user opens settings
        showOpenSettingsDialog(context, "Camera");
      }
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
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true; // Start loading
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

          if (position.isMocked) {
            showMockLocationDialog(context);
          }

          if (mounted) {
            setState(() {
              _locationMessage =
                  'Latitude: ${position.latitude}, Longitude: ${position.longitude}';
              currentLat = position.latitude;
              currentLong = position.longitude;
              _isLoading = true; // Stop loading once location is fetched
            });
          }

          // Fetch the address after getting the coordinates
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
                _isLoading = false; // Stop loading on error
              });
            }
            _showSafeSnackBar('Failed to fetch address: $e');
          }

          // Start the attendance timer
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

              // Clear the location data and navigate back
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
          _isLoading = false; // Stop loading on error
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
      //  _checkPermissionsAndInitializeCamera();
    } else {
      if (mounted) {
        setState(() {
          _isNetworkAvail = false;
        });
      }
    }
  }

  // Fetch the stored user face data from SharedPreferences
  Future<bool> getUserFaceData() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? base64Image = prefs
          .getString('user_face_data')
          ?.replaceFirst('data:image/jpeg;base64,', '');

      if (base64Image == null || base64Image.isEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.all(20),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // You can use a Lottie animation for no internet or any static icon
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 50),
                    SizedBox(height: 20.h),
                    Text(
                      "Face enrollment data not found",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    const Text(
                      'Please contact IT support or try again',
                      textAlign: TextAlign.center,
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
                          //(Platform.isAndroid)?FlutterExitApp.exitApp():FlutterExitApp.exitApp(iosForceExit: true);// Close the dialog
                          Navigator.pop(context); // Close the dialog
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        child: Text(
                          "Okay",
                          style:
                              TextStyle(fontSize: 16.sp, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }
        return false;
      }

      fetchedImageBytes = base64Decode(base64Image);
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

  @override
  Widget build(BuildContext context) {
    return (_isAuthenticating)
        ? Scaffold(
            body: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: LottieBuilder.asset(
                  'assets/animations/face_authenticating.json', // Put the correct asset path for no internet animation
                  repeat: true,
                ),
              ),
            ),
          )
        : (hasFaceData)
            ? Scaffold(
                backgroundColor: Colors.white,
                extendBodyBehindAppBar: !_isLoading?true:false,
                appBar: const GlassAppBar(title: 'MCD SMART', isLayoutScreen: false),
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
                                    child: Transform.rotate(
                                      angle: -pi /
                                          2, // 90 degrees in radians (clockwise)
                                      child: CircleAvatar(
                                        radius: 100,
                                        backgroundImage:
                                            MemoryImage(fetchedImageBytes!),
                                      ),
                                    ),
                                  ),
                                  // Center(
                                  //   child: SizedBox(
                                  //     height: 300,
                                  //     width: 300,
                                  //     child: (image!=null)?Image.memory(image!,
                                  //         fit: BoxFit.cover):SizedBox(),
                                  //   ),
                                  // ),
                                  SizedBox(
                                    height: 10.h,
                                  ),
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
                                  SizedBox(
                                    height: 20.h,
                                  ),
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
                                  SizedBox(
                                    height: 10.h,
                                  ),
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
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: TextField(
                                          controller: remarkController,
                                          maxLines: 5,
                                          decoration: const InputDecoration(
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
                                        onPressed: (currentLat != 0.0 ||
                                                currentLat != null)
                                            ? () {
                                                setState(() {
                                                  showLoader = true;
                                                  initialize();
                                                  Future.delayed(const Duration(
                                                          seconds: 3))
                                                      .then((_) {
                                                    showLoader = false;
                                                  });
                                                });
                                              }
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xff111184),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ), // Button is enabled only when _isButtonEnabled is true
                                        child: (showLoader)
                                            ? Center(
                                                child: SizedBox(
                                                  height: 20.h,
                                                  width: 20.w,
                                                  child:
                                                      const CircularProgressIndicator(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              )
                                            : (currentLat != 0.0 ||
                                                    currentLat != null)
                                                ? const Text(
                                                    "Proceed",
                                                    style: TextStyle(
                                                        color: Colors.white),
                                                  )
                                                : const Text(
                                                    "Check Location Permission to enable this button",
                                                    style: TextStyle(
                                                        color: Colors.white),
                                                  )),
                                  ),
                                  //  SizedBox(height: 10.h),
                                  //  (imageDuringLivelinessCheck!=null)?Image.memory(imageDuringLivelinessCheck!,height: 100,width: 100,):SizedBox()
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
