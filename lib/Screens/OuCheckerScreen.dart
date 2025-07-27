import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import 'package:mcd_attendance/Helpers/Constant.dart';
import 'package:mcd_attendance/Screens/Widgets/GlassAppbar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart'as http;
import '../Helpers/ApiBaseHelper.dart';
import '../Helpers/AppBtn.dart';
import '../Helpers/Session.dart';
import '../Helpers/String.dart';
import '../Model/Employee.dart';
import '../Model/EmployeeHistoryModel.dart';
import '../Utils/fake_location_util.dart';
import 'dart:math' as math;
import 'Widgets/DialogBox.dart';
import 'package:location/location.dart' as loc;

class OuCheckerScreen extends StatefulWidget {
  const OuCheckerScreen({super.key,});

  @override
  State<OuCheckerScreen> createState() => _OuCheckerScreenState();
}

class _OuCheckerScreenState extends State<OuCheckerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final fm.MapController _mapController = fm.MapController();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController remarkController = TextEditingController();

  String _locationMessage = '';
  double currentLat = 0.0;
  double currentLong = 0.0;
  bool _isLoading = true;
  bool _isNetworkAvail = true;
  bool _isDisposed = false;
  bool showLoader = false;
  String address = '';
  String locationStatus = '';
  String base64Image = '';
  String inTime = '';
  String error = '';
  double? height;
  double? width;
  bool isLoading = false;
  late AnimationController _animationController;
  late CameraController cameraController;
  late Future<void> initializeControllerFuture;
  Timer? _attendanceTimer;
  ApiBaseHelper apiBaseHelper = ApiBaseHelper();
  File displayImage = File('');
  Uint8List? image;
  Uint8List? imageDuringLivelinessCheck;
  Widget? _cachedMapWidget;
  List<MappingData> ouData = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkInternetAndInitialize();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _animationController.dispose();
    _attendanceTimer?.cancel();
    cameraController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    remarkController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    height = size.height;
    width = size.width;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(Duration.zero, () {
        if (mounted && !_isDisposed) {
          // Skip mock location check for iOS
          if (!Platform.isIOS) {
            checkForMockLocation(context);
          }
        }
      });
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
          NoInternetDialog(onRetry: () => (Platform.isAndroid)?FlutterExitApp.exitApp():FlutterExitApp.exitApp(iosForceExit: true)),
        );
        return;
      }

      debugPrint("Current time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}");

      // 3. Get location and process sequentially
      await _executeWithMountedCheck(() async {
        await _getCurrentLocation();

        // Ensure we have valid coordinates before getting distance
        if (currentLat != 0.0 && currentLong != 0.0) {
          await _executeWithMountedCheck(() async {
            if (mounted && !_isDisposed) {
              _cachedMapWidget = _buildMapView();
            }
          }, 'getDistanceData');
        }
      }, '_getCurrentLocation');

      // 4. Run safety checks
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

  Future<void> _executeWithMountedCheck(FutureOr<void> Function() operation, String operationName) async {
    try {
      if (mounted && !_isDisposed) {
        await operation();
      }
    } catch (e) {
      debugPrint('Error in $operationName: $e');
    }
  }

  Future<void> fetchOuData() async {
    if (!mounted) return;

    setState(() {
      showLoader = true;
      isLoading = true;
    });

    const String url = newBaseUrl;
    const String token =
        'eyJhbGciOiJIUzI1NiJ9.e30.g2PzdcLXSunm0_ZW-5d9ptZSpeXZi0qsh_sTuTTojRs';

    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    var request = http.Request('GET', Uri.parse(url));
    var body = json.encode({
      "module": "ou",
      "event": "checker",
      "params": {
        "emp_bmid": userBmid,
        "latitude": currentLat,
        "longitude": currentLong,
      }
    });

    request.body = body;
    request.headers.addAll(headers);

    try {
      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> jsonData = json.decode(responseBody);

        final mappingResponse = MappingResponse.fromJson(jsonData);

        if (mounted) {
          setState(() {
            ouData = mappingResponse.data; // List<MappingData>
          });
          debugPrint("ouData= ${ouData[0].status},${ouData[0].distance}");
        }
      } else {
        _showNullValueError("fetchOuData Api: HTTP ${response.statusCode}");
      }
    } catch (e) {
      _showNullValueError("fetchOuData Api Exception: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          showLoader = false;
        });
      }
    }
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


  Future<void> _showSafeDialog(Widget dialog) async {
    if (!mounted || _isDisposed) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => dialog,
    );
  }

  void _showSafeSnackBar(String message) {
    if (!mounted || _isDisposed) return;

    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  Future<void> getPlacemarks(double lat, double long) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        if (mounted && !_isDisposed) {
          setState(() {
            address = "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
          });
        }
      } else if (mounted && !_isDisposed) {
        setState(() => address = "No address available");
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() => address = "Failed to get address: $e");
      }
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
      if (statusCamera == PermissionStatus.permanentlyDenied) {
        await _showSafeDialog(_buildPermissionDialog("Camera"));
      }
    }

    if (statusStorage != PermissionStatus.granted) {
      if (statusStorage == PermissionStatus.permanentlyDenied) {
        await _showSafeDialog(_buildPermissionDialog("Storage"));
      }
    }
  }

  Widget _buildPermissionDialog(String permissionName) {
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
            onPressed: () async => await openAppSettings(),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    final loc.Location locationService = loc.Location();
    try {
      if (!mounted || _isDisposed) return;
      setState(() => _isLoading = true);

      // Show system GPS enable dialog
      bool serviceEnabled = await locationService.requestService();
      if (!serviceEnabled) {
        _showSafeSnackBar("Location services required");
        if (mounted) {
          Navigator.pop(context); // Go back if user cancels
        }
        return;
      }

      Map<Permission, PermissionStatus> status = await [Permission.location].request();
      if (status[Permission.location]!.isGranted) {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best);

        if(!Platform.isIOS){
          if (position.isMocked) {
            await _showSafeDialog(showMockLocationDialog(context));
          }
        }

        if (mounted && !_isDisposed) {
          setState(() {
            _locationMessage = 'Latitude: ${position.latitude}, Longitude: ${position.longitude}';
            currentLat = position.latitude;
            currentLong = position.longitude;
          });
        }

        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          ).timeout(const Duration(seconds: 5));

          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            address = "${place.name}, ${place.locality}, ${place.country}";
            if (mounted && !_isDisposed) {
              setState(() => _locationMessage = address);
            }
          }
        } catch (e) {
          if (mounted && !_isDisposed) {
            setState(() => _locationMessage = 'Failed to get address: $e');
          }
          _showSafeDialog(LocationExceptionDialog(errorDetails: e.toString()));
          _showSafeSnackBar('Failed to fetch address: $e');
        }

      } else {
        _showSafeSnackBar("Location permission is required.");
        await openAppSettings();
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() => _locationMessage = 'Failed to get location: $e');
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> checkNetwork() async {
    _isNetworkAvail = await isNetworkAvailable();
    if (mounted && !_isDisposed) {
      setState(() {});
    }
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

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Widget _buildTableRow(String label1, String value1) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBorderedCell(label1, value1),
      ],
    );
  }

  Widget _buildTableRowForTwo(String label1, String value1,String label2, String value2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBorderedCell(label1, value1),
        _buildBorderedCell(label2, value2),
      ],
    );
  }

  Widget _buildBorderedCell(String label, String value) {
    return Expanded(
      flex: 1,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const GlassAppBar(title: 'MCD PRO', isLayoutScreen: false),
        body: _isNetworkAvail
            ? !_isLoading && _cachedMapWidget != null
            ? SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.vertical,
          ),
          child: Column(
            children: [
              SizedBox(
                height: height! * 0.25,
                width: double.infinity,
                child: _cachedMapWidget,
              ),
              SizedBox(
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTableRow('Bmid', userBmid.toString(),),
                            _buildTableRow('Name', empName?? ''),
                            _buildTableRowForTwo('Current Latitude', currentLat.toStringAsFixed(6),'Current Longitude', currentLong.toStringAsFixed(6)),
                          ],
                        )

                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      SizedBox(height: 10.h),
                      SizedBox(
                        width: double.infinity,
                        height: 50.h,
                        child: ElevatedButton(
                          onPressed:  fetchOuData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff111184),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: showLoader
                              ?  Center(
                            child: SizedBox(
                              height: 20.h,
                              width: 20.w,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          )
                              : const Text(
                            "Verify OU",
                            style: TextStyle(color: Colors.white),
                          )
                        ),
                      ),
                      SizedBox(height: 20.h,),
                  showLoader
                      ? const Center(
                    child: Text(
                      "Fetching please wait...",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  )
                      : ouData.isNotEmpty
                      ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: ouData[0].status == "OUT OF OFFICE"
                              ? Colors.red
                              : Colors.green,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: (ouData[0].status == "OUT OF OFFICE"
                            ? Colors.red
                            : Colors.green)
                            .withOpacity(0.1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            ouData[0].status,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: ouData[0].status == "OUT OF OFFICE"
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ouData[0].distance,
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                      : const SizedBox()// Show nothing if no data yet and not loading
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
            : const Center(
          child: Text('No internet available'),
        ),
      ),
    );
  }
}

class MappingResponse {
  final String msg;
  final int code;
  final List<MappingData> data;

  MappingResponse({
    required this.msg,
    required this.code,
    required this.data,
  });

  factory MappingResponse.fromJson(Map<String, dynamic> json) {
    return MappingResponse(
      msg: json['msg'] ?? '',
      code: json['code'] ?? 0,
      data: (json['data'] as List<dynamic>)
          .map((item) => MappingData.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'msg': msg,
    'code': code,
    'data': data.map((e) => e.toJson()).toList(),
  };
}

class MappingData {
  final String status;
  final String distance;

  MappingData({
    required this.status,
    required this.distance,
  });

  factory MappingData.fromJson(Map<String, dynamic> json) {
    return MappingData(
      status: json['status'] ?? '',
      distance: json['distance'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'distance': distance,
  };
}
