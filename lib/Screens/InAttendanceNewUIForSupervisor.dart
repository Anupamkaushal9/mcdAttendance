import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/AppBtn.dart';
import '../Helpers/Session.dart';
import '../Helpers/String.dart';
import '../Model/Employee.dart';
import '../Model/EmployeeHistoryModel.dart';
import '../Model/SupervisorEmployeeModel.dart';
import '../Utils/fake_location_util.dart';
import 'dart:math' as math;

import 'Widgets/DialogBox.dart';

class InAttendanceNewUiForSupervisorScreen extends StatefulWidget {
  final List<EmpHistoryData>? empHistoryData;
  final String bmid;
  final String guid;
  final List<SupervisorEmployeeModel>? employeeInfoList;
   const InAttendanceNewUiForSupervisorScreen(
      {super.key, this.empHistoryData, required this.bmid,required this.guid,required this.employeeInfoList});

  @override
  State<InAttendanceNewUiForSupervisorScreen> createState() =>
      _InAttendanceNewUiForSupervisorScreenState();
}

class _InAttendanceNewUiForSupervisorScreenState extends State<InAttendanceNewUiForSupervisorScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final fm.MapController _mapController = fm.MapController();
  String _locationMessage = '';
  double currentLat = 0.0;
  double currentLong = 0.0;
  bool _isLoading = true;
  bool _isNetworkAvail = true;
  Animation? buttonSqueezeAnimation;
  AnimationController? buttonController;
  double deviceWidth =
      WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width;
  String address = '';
  late Future<void> _initializeControllerFuture;
  bool _isCameraInitialized = false;
  int _remainingTime = 180; // 2 minutes for attendance
  Timer? _attendanceTimer;
  bool _isAuthenticating = false;
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  File displayImage = File('');
  String error = '';
  String locationStatus = '';
  String base64Image = '';
  Uint8List? image;
  Uint8List? imageDuringLivelinessCheck;
  String inTime = '';
  bool showLoader = false;
  late CameraController cameraController;
  late Future<void> initializeControllerFuture;
  bool isCameraInitialized = false;
  final TextEditingController remarkController = TextEditingController();
  Widget? _cachedMapWidget;
  double? height;
  double? width;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkInternetAndInitialize();
  }

  Future<void> _checkInternetAndInitialize() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return NoInternetDialog(
            onRetry: () {
              (Platform.isAndroid)?FlutterExitApp.exitApp():FlutterExitApp.exitApp(iosForceExit: true);
            },
          );
        },
      );
      return;
    }
    getLastAttendance();
    await _checkPermissionsAndInitializeCamera();
    print("date time");
    print(DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()));
    await _getCurrentLocation().then((_) async {
      await getOrgBasicGuidSharedPref();
      await getDistanceData();
      _cachedMapWidget = _buildMapView();
    });

    WidgetsBinding.instance.addObserver(this);
    checkForMockLocation(context);
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final size = MediaQuery.of(context).size;

    height = size.height;
    width = size.width;

    // (Optional) You can also calculate percentages here
    print('Height: $height, Width: $width');
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

  Future<void> getOrgBasicGuidSharedPref() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        orgUnitBasicGuid = prefs.getString('orgUnitBasicGuid')!;
      });
    }
    print('orgUnitBasicGuid = $orgUnitBasicGuid');
  }

  Future<void> _checkPermissionsAndInitializeCamera() async {
    if (await Permission.camera.request().isGranted) {
      await _initializeCamera();
    } else {
      print('Camera permission denied');
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back);
    cameraController = CameraController(frontCamera, ResolutionPreset.high);
    initializeControllerFuture = cameraController.initialize().then((_) {
      isCameraInitialized = true;
    });
  }

  Future<void> _clearPreference() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.clear();
  }

  getLastAttendance() async {
    print('last attendance api is running');
    await Future.delayed(const Duration(seconds: 2));
    var parameter = {
      "empGuid": widget.guid,
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
                  inTimingForSuper = '';
                  outTimingForSuper = '';
                } else {
                  // Same day → keep them
                  inTimingForSuper = inTime;
                  outTimingForSuper = outTime;
                }
              } else if (inTime.isNotEmpty && outTime.isEmpty) {
                // ✅ inTime exists, outTime missing
                DateTime inDateTime = DateTime.parse(inTime);
                Duration difference = now.difference(inDateTime);

                if (difference.inHours >= 20) {
                  // More than 20 hours passed → clear both
                  inTimingForSuper = '';
                  outTimingForSuper = '';
                } else {
                  // Less than 20 hours → keep inTime, outTime stays empty
                  inTimingForSuper = inTime;
                  outTimingForSuper = outTime;
                }
              } else {
                // ❌ inTime is empty → clear both
                inTimingForSuper = '';
                outTimingForSuper = '';
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
              if(!isFreshUserForSupervisor)
              {
                _clearPreference();
                showDialog(
                  context: context,
                  builder: (_) => WillPopScope(
                    onWillPop: () async => false,
                    child: const SomethingWentWrongDialog(errorDetails: '',),
                  ),
                );
              }
            }
          }

          if (error.isNotEmpty) {
            print('Error: $error');
          }
        }
      },
      onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      },
    );
  }

  Future<void> saveInAttendance() async {
    setState(() {
      _isLoading = true;
    });

    inTimingForSuper = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    print("===== Attendance Data Submission =====");
    print("Address (inLocAddInfo): $address");
    print("Latitude (inLatAdd): ${currentLat.toString()}");
    print("Longitude (inLonAdd): ${currentLong.toString()}");
    print("Captured By (attCaptureByGuid): ${widget.bmid}");
    print("Organization GUID (orgGuid): 15f5e483-42e2-48ea-ab76-a4e26a20011c");
    print("Device ID (deviceId): $deviceUniqueId");
    print("In Time (inTime): $inTimingForSuper");
    print("Employee GUID (empGuid): ${widget.bmid}");
    print("Employee Picture (inEmpPic - base64): $base64Image");
    print("======================================");

    var userData = {
      "inLocAddInfo": address,
      "inLatAdd": currentLat.toString(),
      "inLonAdd": currentLong.toString(),
      "attCaptureByGuid": widget.guid,
      "orgGuid": "15f5e483-42e2-48ea-ab76-a4e26a20011c",
      "deviceId": deviceUniqueId,
      "inTime": inTimingForSuper,
      "empGuid": widget.guid,
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
                child: SuccessDialogNormalForSupervisor(
                  messageApi: message, guid: widget.guid,
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
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
                  messageApi: errorMessage,
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

        setState(() {
          _isLoading = false;
        });

        String error = response['error'] ?? 'Unknown error occurred';
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Failed to save attendance: $error")),
              );
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error occurred: $e")),
            );
          }
        });
      }
    }
  }

  Future<void> saveOutAttendance() async {
    setState(() {
      _isLoading = true;
    });

    outTimingForSuper = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    var userData = {
      "empGuid": widget.guid,
      "deviceId": deviceUniqueId,
      "orgGuid": orgGuid,
      "outEmpPic": base64Image,
      "inTime": widget.empHistoryData![0].inTime,
      "outTime": outTimingForSuper,
      "outLatAdd": currentLat.toString(),
      "outLonAdd": currentLong.toString(),
      "outLocAddInfo": address,
      "attCaptureByGuid": widget.guid,
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
                child: SuccessDialogNormalForSupervisor(
                  messageApi: message,
                  guid: widget.guid,
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
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
                  messageApi: errorMessage,
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

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Failed to save out attendance: $message')),
              );
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('An error occurred: $e')),
            );
          }
        });
      }
    }
  }

  getDistanceData() async {
    setState(() {
      _isLoading = true; // Set loading to true when API call starts
    });

    // Prepare the request parameters
    var parameter = {
      "inLatAdd": currentLat,
      "inLonAdd": currentLong,
      "orgUnitGuid": orgUnitBasicGuidForSuper,
    };

    try {
      // Use apiBaseHelper to make the POST request
      var responseData =
      await apiBaseHelper.postAPICall(getDistanceApi, parameter);

      // Check if response is in the expected format
      if (responseData is Map<String, dynamic>) {
        String status = responseData['status'].toString();
        String distance = responseData['distance'].toString();

        print("API Response: $responseData");

        if (status == 'TRUE') {
          // Process the response if status is 'TRUE'
          if (distance == 'TRUE') {
            // In Office - Call the initialize function
            setState(() {
              locationStatus = "In office";
            });
          } else {
            // Out of Office - Show dialog and request focus
            // You can also trigger the focus within this dialog callback
            setState(() {
              locationStatus = "Out of office";
            });
            showDialog(
              barrierDismissible: false,
              context: context,
              builder: (BuildContext context) {
                return WillPopScope(
                    onWillPop: () async => false,
                    child: const OutOfOfficeDialog());
              },
            );
          }
        } else {
          // Handle API response failure (status = 'FALSE')
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to fetch distance: $status")),
          );
        }
      } else {
        throw Exception("Invalid response format.");
      }
    } catch (e) {
      // Catch any other errors (network issues, parsing issues, etc.)
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      // Ensure loading indicator is hidden after API call
      if (mounted) {
        setState(() {
          _isLoading = false; // Hide the loading indicator after processing
        });
      }
    }
  }

  Widget buildCameraPreview() {
    var tmp = MediaQuery.of(context).size;

    final screenH = math.max(tmp.height, tmp.width);
    final screenW = math.min(tmp.height, tmp.width);

    tmp = cameraController!.value.previewSize!;

    final previewH = math.max(tmp.height, tmp.width);
    final previewW = math.min(tmp.height, tmp.width);
    final screenRatio = screenH / screenW;
    final previewRatio = previewH / previewW;

    return Padding(
      padding: const EdgeInsets.all(0.0),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: OverflowBox(
              maxHeight: screenRatio > previewRatio
                  ? screenH
                  : screenW / previewW * previewH,
              maxWidth: screenRatio > previewRatio
                  ? screenH / previewH * previewW
                  : screenW,
              child: Transform(
                alignment: Alignment.center,
                transform: (Platform.isAndroid)?Matrix4.rotationY(3.14159):Matrix4.rotationY(0), // Flip horizontally
                child: Transform.scale(
                  scale: 0.4,
                  child: CameraPreview(
                    cameraController!,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _attendanceTimer?.cancel();
    buttonController?.dispose();
    super.dispose();
  }

  String formatDateTime(DateTime dateTime) {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return dateFormat.format(dateTime);
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
            ).timeout(Duration(seconds: 5), onTimeout: () {
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to fetch address: $e')),
            );
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

                  // Clear the location data and navigate back
                  if (mounted) {
                    setState(() {
                      currentLat = 0.0;
                      currentLong = 0.0;
                      address = '';
                    });
                  }
                  showDialog(
                      barrierDismissible: false,
                      context: context,
                      builder: (_) => WillPopScope(
                          onWillPop: () async => false,
                          child: const TimeOutDialog())).then((_) {
                    if (mounted) {
                      Navigator.of(context, rootNavigator: true)
                          .popUntil((route) => route.isFirst);
                    }
                  });
                }
              });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission is required.")),
          );
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 0.5),
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),
        ),
        title: const Text("MCD SMART"),
        centerTitle: true,
      ),
      body: _isNetworkAvail
          ? !_isLoading && !_isAuthenticating && _cachedMapWidget!=null && isCameraInitialized
          ? SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.vertical,),
        child: Column(
          children: [
            /// 🔹 Map View - Top 25%
            SizedBox(
                height: height! * 0.25,
                width: double.infinity,
                child:
                _cachedMapWidget // Replace with your map widget
            ),

            /// 🔹 Middle Section - 50%
            SizedBox(
              child: Row(
                children: [
                  /// 🔸 Left side info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locationStatus,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                              (locationStatus == "Out of office")
                                  ? Colors.red
                                  : Colors.green,
                              fontSize: 20.sp,
                            ),
                          ),
                           SizedBox(height: 10.h),
                           SingleChildScrollView(
                             scrollDirection: Axis.horizontal,
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bmid : ${widget.employeeInfoList!.first.empCode??0}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                 SizedBox(height: 10.h),
                                Text(
                                  'Name : ${widget.employeeInfoList!.first.empName??''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                                 SizedBox(height: 10.h),
                                Text(
                                  'Latitude :${double.parse(currentLat.toStringAsFixed(6))}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                 SizedBox(height: 10.h),
                                Text(
                                  'Longitude : ${double.parse(currentLong.toStringAsFixed(6))}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                 SizedBox(height: 10.h),

                              ],
                                                       ),
                           ),
                          Text(
                            'Mark attendance in: ${_formatDuration(_remainingTime)}',
                            style:  TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// 🔸 Camera Preview
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 200.h,
                        child: buildCameraPreview(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 0, horizontal: 15),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                       TextSpan(
                        text: 'Address: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: address,
                        style:  TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 16.sp,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  softWrap: true,
                ),
              ),
            ),

            /// 🔹 Bottom Section - 25%
            SizedBox(
              height: height! * 0.25,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: remarkController,
                        scrollPadding: const EdgeInsets.only(
                            bottom: 120),
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Type your message here',
                        ),
                      ),
                    ),
                     SizedBox(height: 10.h),
                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: (currentLat != 0.0)
                            ? () async {
                          await _handleAttendance();
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff111184),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: showLoader
                            ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                            : (inTimingForSuper.isEmpty)?const Text(
                          "Mark In Attendance",
                          style: TextStyle(color: Colors.white),
                        ):const Text(
                          "Mark Out Attendance",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      )
          : Center(
        child: LottieBuilder.asset(
          'assets/animations/loading_animation.json',
          height: 50.h,
          width: 50.w,
        ),
      )
          : noInternet(context),
    );
  }

  /// 🔄 Map widget placeholder
  Widget _buildMapView() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: fm.FlutterMap(
          options: fm.MapOptions(
            initialCenter: LatLng(currentLat, currentLong),
          ),
          children: [
            fm.TileLayer(
              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.yourapp',
            ),
            fm.MarkerLayer(
              markers: [
                fm.Marker(
                  point: LatLng(currentLat, currentLong),
                  width: 80.w,
                  height: 80.h,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 📸 Attendance handler
  Future<void> _handleAttendance() async {
    try {
      if (cameraController != null) {
        final image = await cameraController!.takePicture();
        if (image.path.isNotEmpty) {
          Uint8List imageBytes = await image.readAsBytes();
          base64Image = base64Encode(imageBytes);
          if (widget.empHistoryData != null &&
              widget.empHistoryData!.isNotEmpty) {
            print("inTiming when handling attendance===$inTimingForSuper");
            if (inTimingForSuper.isNotEmpty) {
              await saveOutAttendance();
              await getLastAttendance();
            } else {
              await saveInAttendance();
              await getLastAttendance();
            }
          } else {
            await saveInAttendance();
            await getLastAttendance();
          }
        }
      }
    } catch (e) {
      print('Error capturing photo: $e');
    }
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
