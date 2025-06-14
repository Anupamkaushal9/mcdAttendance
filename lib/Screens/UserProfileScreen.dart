import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:palette_generator/palette_generator.dart';

import '../Helpers/String.dart';
import 'Widgets/DialogBox.dart';
import 'Widgets/GlassAppbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Color? _dominantColor;
  bool isLoading = false;

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
          builder: (BuildContext context) => NoInternetDialog(
            onRetry: () => Platform.isAndroid
                ? FlutterExitApp.exitApp()
                : FlutterExitApp.exitApp(iosForceExit: true),
          ));
          return;
      }
          _extractDominantColor();
    }

  Future<void> _extractDominantColor() async {
    if (userPhoto != null && userPhoto!.isNotEmpty) {
      try {
        final generator = await PaletteGenerator.fromImageProvider(
          MemoryImage(userPhoto!),
          size: const Size(200, 200),
        );
        setState(() {
          _dominantColor = _darkenColor(generator.dominantColor?.color ?? Colors.blue.shade900, 0.6);
        });
      } catch (e) {
        setState(() => _dominantColor = Colors.blue.shade900);
      }
    } else {
      setState(() => _dominantColor = Colors.blue.shade900);
    }
  }

  Color _darkenColor(Color color, double factor) => Color.fromARGB(
    color.alpha,
    (color.red * (1 - factor)).clamp(0, 255).toInt(),
    (color.green * (1 - factor)).clamp(0, 255).toInt(),
    (color.blue * (1 - factor)).clamp(0, 255).toInt(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GlassAppBar(title: 'MY PROFILE', isLayoutScreen: false),
      body: _dominantColor == null
          ? Center(
        child: Lottie.asset(
          'assets/animations/loading_animation.json',
          height: 50.h,
          width: 50.w,
        ),
      )
          : SingleChildScrollView(
        child: Column(
          children: [
            ProfileHeader(
              dominantColor: _dominantColor!,
              avatar: userPhoto?.isNotEmpty ?? false
                  ? MemoryImage(userPhoto!) as ImageProvider<Object>
                  :  const AssetImage('assets/images/dummyUser.jpg'),
              title: empTempData.first.empName ?? '',
              subtitle: empTempData.first.empDesignation ?? 'Unknown Designation',
            ),
            UserInfoSection(dominantColor: _dominantColor!),
          ],
        ),
      ),
    );
  }
}

class ProfileHeader extends StatelessWidget {
  final Color dominantColor;
  final ImageProvider<Object> avatar;
  final String title;
  final String subtitle;

  const ProfileHeader({
    super.key,
    required this.dominantColor,
    required this.avatar,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 170.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [dominantColor, dominantColor.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Image.asset("assets/images/mcd_building.jpg",fit: BoxFit.fill,width: double.infinity,height: 200.h,),
        ),
        SafeArea(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 100),
            child: Column(
              children: [
                Avatar(image: avatar, dominantColor: dominantColor),
                SizedBox(height: 12.h),
                Text(
                  title,
                  style:  TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style:  TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class Avatar extends StatelessWidget {
  final ImageProvider<dynamic> image;
  final Color dominantColor;

  const Avatar({
    super.key,
    required this.image,
    required this.dominantColor,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 70,
      backgroundColor: dominantColor,
      child: Transform.rotate(
        angle: -pi / 2,
        child: CircleAvatar(
          radius: 66,
          backgroundImage: image as ImageProvider<Object>,
        ),
      ),
    );
  }
}

class UserInfoSection extends StatelessWidget {
  final Color dominantColor;

  const UserInfoSection({super.key, required this.dominantColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        shadowColor: Colors.teal,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10,horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [dominantColor.withOpacity(0.1), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              _buildInfoTile(
                icon: Icons.email,
                title: 'Email',
                value: empTempData.first.email,
                color: dominantColor
              ),
              _buildInfoTile(
                icon: Icons.phone,
                title: 'Mobile',
                value: empTempData.first.mobile,
                color: dominantColor
              ),
              _buildInfoTile(
                icon: Icons.badge,
                title: 'Employee ID',
                value: empTempData.first.empCode,
                color: dominantColor
              ),
              _buildInfoTile(
                icon: Icons.work,
                title: 'Designation',
                value: empTempData.first.empDesignation,
                color: dominantColor
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String? value,
    required Color? color
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color),
          SizedBox(width: 10.w),
          Text("$title:",
              style:
               TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
           SizedBox(width: 10.w),
          Expanded(
            child: Text(
              value ?? "Not Available",
              style:  TextStyle(fontSize: 16.sp, color: Colors.black54),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}