import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_face_api/flutter_face_api.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mcd_attendance/main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

import '../../Helpers/ApiBaseHelper.dart';
import '../../Helpers/Session.dart';
import '../../Helpers/String.dart';
import '../../Model/Employee.dart';
import '../../Model/EmployeeHistoryModel.dart';
import '../../Utils/fake_location_util.dart';
import 'DialogBox.dart';

class InfoDialog extends StatefulWidget {
  final List<EmpHistoryData>? empHistoryData;
  final List<EmpData>? employee;
  const InfoDialog(
      {Key? key, required this.empHistoryData, required this.employee})
      : super(key: key);

  @override
  State<InfoDialog> createState() => _InfoDialogState();
}

class _InfoDialogState extends State<InfoDialog> with WidgetsBindingObserver {
  String _locationMessage = '';
  double currentLat = 0.0;
  double currentLong = 0.0;
  bool _isLoading = true;
  bool loading = false;
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
  bool _disposed = false;

  livelinessCheck() async {
    await checkLiveliness();
  }

  @override
  void initState() {
    super.initState();
    debugPrint("date time");
    debugPrint(DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()));
    getUserFaceData();
    _getCurrentLocation().then((_) {
      getDistanceData();
    });

    WidgetsBinding.instance.addObserver(this);
    checkForMockLocation(context);
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    checkNetwork();
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

  saveAttendanceInTime(String inTime) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('attendance_in_time', inTime);
  }

  getAttendanceInTime() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    inTime = prefs.getString('attendance_in_time')!;
  }

  Future<void> saveInAttendance() async {
    if(mounted&&!_disposed)
      {
        setState(() {
          _isLoading = true; // Set loading to true when API call starts
        });
      }


    await saveAttendanceInTime(
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()));

    await getAttendanceInTime();

    String userInTime = inTime;
    debugPrint("UserInTime"+userInTime);


        showDialog(
          context: navigatorKey.currentContext!,
          builder: (_) => const SuccessDialog(),
        );


    var userData = {
      "inLocAddInfo": address,
      "inLatAdd": currentLat.toString(),
      "inLonAdd": currentLong.toString(),
      "attCaptureByGuid": empGuid,
      "orgGuid": "15f5e483-42e2-48ea-ab76-a4e26a20011c",
      "deviceId": deviceUniqueId,
      "inTime": userInTime,
      "empGuid": empGuid,
      "inEmpPic": base64Image,
    };

    debugPrint("Sending User Data to API:");
    userData.forEach((key, value) => debugPrint('$key: $value'));

    // try {
    //   // Make the API call using the custom API helper (postAPICall method)
    //   var response =
    //       await apiBaseHelper.postAPICall(saveInAttendanceApi, userData);
    //
    //   // Ensure the response is in the expected format (JSON)
    //   if (response is String) {
    //     response = json.decode(response);
    //   }
    //
    //   String status = response['status'].toString();
    //   String message = response['message'] ?? 'No message provided';
    //
    //   print("API Response: $response");
    //
    //   if (status == 'TRUE') {
    //     // Success Response
    //     setState(() {
    //       _isLoading = false;
    //     });
    //
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(content: Text(message)),
    //     );
    //
    //     showDialog(
    //       context: context,
    //       builder: (_) => const SuccessDialog(),
    //     );
    //   } else {
    //     // Failure Response
    //     setState(() {
    //       _isLoading = false;
    //     });
    //
    //     String error = response['error'] ?? 'Unknown error occurred';
    //     // Show detailed error message via SnackBar
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(content: Text("Failed to save attendance: $error")),
    //     );
    //   }
    // } catch (e) {
    //   // Handle any unexpected errors
    //   setState(() {
    //     _isLoading = false;
    //   });
    //
    //   String errorMessage = e.toString();
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text("Error occurred: $errorMessage")),
    //   );
    // }
  }

  Future<void> saveOutAttendance() async {
    setState(() {
      _isLoading = true; // Show loading spinner
    });

    await getAttendanceInTime();

    var userData = {
      "empGuid": empGuid,
      "deviceId": deviceUniqueId,
      "orgGuid": orgGuid,
      "outEmpPic": base64Image,
      "inTime": inTime,
      "outTime": DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      "outLatAdd": currentLat.toString(),
      "outLonAdd": currentLong.toString(),
      "outLocAddInfo": address,
      "attCaptureByGuid": empGuid,
    };

    try {
      // Make API request using ApiBaseHelper
      final response = await apiBaseHelper.postAPICall(
        saveOutAttendanceApi,
        userData,
      );

      // Handle API response
      String status = response['status'] ?? 'FALSE';
      String message = response['message'] ?? 'Unknown Error';

      if (status == 'TRUE') {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );

        // Optionally show a success dialog
        showDialog(
          context: context,
          builder: (_) => const SuccessDialog(), // Modify the dialog as needed
        );
      } else {
        // Handle error response from API
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save out attendance: $message')),
        );
      }
    } catch (e) {
      // Handle any exceptions during the API call
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
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
      "orgUnitGuid": orgUnitBasicGuid,
    };

    try {
      // Use apiBaseHelper to make the POST request
      var responseData =
          await apiBaseHelper.postAPICall(getDistanceApi, parameter);

      // Check if response is in the expected format
      if (responseData is Map<String, dynamic>) {
        String status = responseData['status'].toString();
        String distance = responseData['distance'].toString();

        debugPrint("API Response: $responseData");

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
                return const OutOfOfficeDialog();
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

  @override
  void dispose() {
    _disposed = true;
    _attendanceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String formatDateTime(DateTime dateTime) {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return dateFormat.format(dateTime);
  }

  Future<bool> initialize() async {
    bool returndata = true;

    // Show loading dialog
    setState(() {
      loading = true; // Show ProgressIndicator or loading dialog
    });

    try {
      _status = "Initializing...";
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
        // Wait for 3 seconds before closing the dialog
        Future.delayed(const Duration(seconds: 3), () {
          Navigator.pop(context); // Close the dialog after 3 seconds
        });
      } else {
        returndata = false;
      }
    } catch (e) {
      debugPrint("error license $e");
      returndata = false;
    } finally {
      // Hide loading dialog
      setState(() {
        loading = true; // Hide ProgressIndicator
      });
    }

    debugPrint('return data $returndata');
    return returndata;
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
  void matchFaces() async {
    debugPrint("mfImage1 $mfImage1  mfImage2 $mfImage2");
    var mfImage3 = MatchFacesImage(fetchedImageBytes!, ImageType.LIVE);
    try {
      // Check if both images (livenessImage and captureResultImage) are available
      if (mfImage1 == null || mfImage2 == null || fetchedImageBytes == null) {
        _status = "All images are required!";
        return;
      }

      _status = "Processing status";
      if (mounted && !_disposed) {
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

      // Perform face matching for captureResult.image vs fetchedImageBytes
      var request2 = MatchFacesRequest([mfImage2!, mfImage3!]);
      var response2 = await faceSdk.matchFaces(request2);
      debugPrint("Capture vs Fetched face match response $response2");

      var split2 = await faceSdk.splitComparedFaces(response2.results, 0.75);
      var match2 = split2.matchedFaces;
      debugPrint("Capture vs Fetched face match data $match2");

      bool captureMatchSuccess = false;
      if (match2.isNotEmpty) {
        similarity = "${(match2[0].similarity * 100).toStringAsFixed(2)}%";
        debugPrint("Capture match similarity: $similarity");

        if (match2[0].similarity >= 0.75) {
          captureMatchSuccess = true;
        }
      }

      // If both matches pass, proceed with success logic
      if (livenessMatchSuccess && captureMatchSuccess) {
        // Handle attendance saving based on empHistoryData status
        if(mounted && _disposed)
          {
            setState(() {
              _isAuthenticating = false; // Reset authentication flag
                  if (widget.empHistoryData != null && widget.empHistoryData!.isNotEmpty) {
                if (widget.empHistoryData![0].inTime != null) {
                  // If empHistoryData is not empty and inTime exists, save out attendance
                  saveOutAttendance();
                } else {
                  // If empHistoryData is not empty but inTime doesn't exist, save in attendance
                  saveInAttendance();
                }
              } else {
                // If empHistoryData is empty (first attendance), save in attendance
                saveInAttendance();
              }
            });
          }

      } else {
        // If either match fails, show failure dialog
        if (mounted && !_disposed) {
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
      }
    } catch (e) {
      debugPrint("Error matching faces: $e");

      // Show the failure dialog on error
      if (mounted && !_disposed) {
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
      if (mounted && !_disposed) {
        setState(() {
          _isAuthenticating = false; // Reset authentication flag
        });
      }
    }
  }

  // Perform liveness check
  Future<void> checkLiveliness() async {
    try {
      _isLivelinessInProgress = true;

      var result = await faceSdk.startLiveness(
        config: LivenessConfig(
          copyright: false,
          livenessType: LivenessType.ACTIVE,
          torchButtonEnabled: true,
          skipStep: [
            LivenessSkipStep.ONBOARDING_STEP,
            LivenessSkipStep.SUCCESS_STEP,
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
        if (mounted && !_disposed) {
          setState(() {
            livenessStatus = "Liveness check failed!";
          });
        }
      } else {
        if (mounted && !_disposed) {
          setState(() {
            imageDuringLivelinessCheck = result.image;
            livenessStatus = "Liveness Passed: ${result.liveness.name}";
          });
        }
        await captureAndAuthenticate(); // Proceed with face authentication
      }
    } catch (e) {
      debugPrint('Error during liveness check: $e');
      if (mounted && !_disposed) {
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
      showDialog(
          barrierDismissible: false,
          context: context,
          builder: (_) => const TimeOutDialog()).then((_) {
        Navigator.pop(context);
      });
      // Go back to the previous screen
    }
  }

  Future<void> captureAndAuthenticate() async {
    try {
      var captureResult = await faceSdk.startFaceCapture(
        config: FaceCaptureConfig(
            cameraPositionAndroid: 1, cameraPositionIOS: CameraPosition.FRONT),
      );

      if (captureResult.image != null) {
        base64Image = base64Encode(captureResult.image!.image);
        image = captureResult.image!.image;
        setImage(captureResult.image!.image, ImageType.LIVE, 1);
        setImage(imageDuringLivelinessCheck!, ImageType.LIVE, 2);
        matchFaces();
      } else {
        print("capture image is null");
      }
    } catch (e) {
      debugPrint('Error during face capture or authentication: $e');
      if (mounted && !_disposed) {
        setState(() {
          livenessStatus = "Error during face capture or authentication.";
        });
      }
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

  // Function to request permissions
  Future<void> requestPermissions() async {
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
        // Open app settings if permission is permanently denied
        openAppSettings();
      }
    }

    // Handle other permissions like storage
    if (statusStorage != PermissionStatus.granted) {
      if (statusStorage == PermissionStatus.denied) {
        print('Storage permission denied');
      } else if (statusStorage == PermissionStatus.permanentlyDenied) {
        print('Storage permission permanently denied');
        openAppSettings();
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
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
        Navigator.pop(context);
      } else {
        Map<Permission, PermissionStatus> status =
            await [Permission.location].request();

        if (status[Permission.location]!.isGranted) {
          Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high);
          if (position.isMocked) {
            showMockLocationDialog(context);
          }
          if (mounted) {
            setState(() {
              _locationMessage =
                  'Latitude: ${position.latitude}, Longitude: ${position.longitude}';
              currentLat = position.latitude;
              currentLong = position.longitude;
              getPlacemarks(currentLat, currentLong);
              _isLoading = false;
            });
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
  Future<void> getUserFaceData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? base64Image = prefs
        .getString('user_face_data')
        ?.replaceFirst('data:image/png;base64,', '');
    if (base64Image != null && base64Image.isNotEmpty) {
      fetchedImageBytes = base64Decode(base64Image);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController remarkController = TextEditingController();
    return (_isLoading)
        ? const Center(child: CircularProgressIndicator())
        : AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.all(5),
            content: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                            radius: 100,
                            backgroundImage: MemoryImage(fetchedImageBytes!)),
                      ),
                      // Center(
                      //   child: SizedBox(
                      //     height: 300,
                      //     width: 300,
                      //     child: (image!=null)?Image.memory(image!,
                      //         fit: BoxFit.cover):SizedBox(),
                      //   ),
                      // ),
                      const SizedBox(
                        height: 10,
                      ),
                      Center(
                        child: Text(
                          locationStatus,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (locationStatus == "Out of office")
                                  ? Colors.red
                                  : Colors.green,
                              fontSize: 20),
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Address',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18.0.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          address,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18.0.sp,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 10.h,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'Latitude : $currentLat, Longitude : $currentLong',
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
                              fontSize: 15.0.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                initialize();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff111184),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ), // Button is enabled only when _isButtonEnabled is true
                            child: (loading)
                                ? const Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    "Proceed",
                                    style: TextStyle(color: Colors.white),
                                  )),
                      ),
                      SizedBox(height: 10.h),
                      (imageDuringLivelinessCheck != null)
                          ? Image.memory(
                              imageDuringLivelinessCheck!,
                              height: 100,
                              width: 100,
                            )
                          : SizedBox()
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}
