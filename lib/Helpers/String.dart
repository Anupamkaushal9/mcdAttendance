import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mcd_attendance/Model/Employee.dart';

import 'Constant.dart';

final Uri getEmpApi = Uri.parse('${baseUrl}emp-search');
final Uri getEmpHistoryApi = Uri.parse('${baseUrl}attendance-history');
final Uri markOutAttendanceApi = Uri.parse('${baseUrl}attendance-history');
final Uri deviceRegistrationStatusApi = Uri.parse('${baseUrl}device-registration-status');
final Uri deviceDeRegistrationApi = Uri.parse('${baseUrl}device-de-registration-request');
final Uri deviceRegistrationApi = Uri.parse('${baseUrl}device-registration-request');
final Uri loginRequestApi = Uri.parse('${baseUrl}login-request');
final Uri OrgListApi = Uri.parse('${baseUrl}org-list');
final Uri getDistanceApi = Uri.parse('${baseUrl}get-distance');
final Uri saveInAttendanceApi = Uri.parse('${baseUrl}save-in-attendance');
final Uri saveOutAttendanceApi = Uri.parse('${baseUrl}save-out-attendance');
final Uri loginApi = Uri.parse('${baseUrl}login-request');
final Uri lastAttendanceApi = Uri.parse('${baseUrl}last-attendance');
final Uri getSupervisorEmpListApi = Uri.parse('${baseUrl}reporting-employees');


String identifier= '';
String userBmid= '';
String empName= '';
String empGuid= '';
String base64Image = '';
String userFaceData = '';
String deviceUniqueId = '';
String orgUnitBasicGuid = '';
String orgUnitBasicGuidForSuper = '';
String orgGuid = '15f5e483-42e2-48ea-ab76-a4e26a20011c';
String inTiming = '';
String outTiming = '';
String inTimingForSuper = '';
String outTimingForSuper = '';
List<EmpData> empTempData = [];
Uint8List? userPhoto = Uint8List(0);
String appVersionFromDevice= '';
String temp = '803F57D2-D3C0-4EE0-B5F4-EA48053C3093';
bool isFreshUser = false;
bool isFreshUserForSupervisor = false;
bool hasSuperVisorAccess = false;
bool faceDataAvailableFromApi = true;
bool isContainDataOne = false;
bool isContainDataTwo = false;
Color bodyColor = Colors.white;
Color appBarColor = const Color(0xff3e7dd5);
Color bottomNavColor = Colors.white30;
String event = '';