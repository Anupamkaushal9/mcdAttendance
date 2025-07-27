class EmployeeHistoryModel {
  String? status;
  List<EmpHistoryData>? empHistoryData;

  EmployeeHistoryModel({this.status, this.empHistoryData});

  factory EmployeeHistoryModel.fromJson(Map<String, dynamic> json) {

    List<EmpHistoryData> empHistoryData = [];
    var order = (json['attendanceXML']['attendanceList'] as List?);

    if (order!.isEmpty) {
      empHistoryData = [];
    } else {
      empHistoryData = order.map((data) => EmpHistoryData.fromJson(data)).toList();
    }
    return EmployeeHistoryModel(
      status : json['status'],
      empHistoryData: empHistoryData,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'emp_data': empHistoryData,
  };
}

class EmpHistoryData {
  String? inTime;
  String? outTime;
  String? inLatAdd;
  String? inLonAdd;
  String? outLatAdd;
  String? outLonAdd;
  String? inLocAddInfo;
  String? locationFlag;
  String? outLocAddInfo;
  String? attCaptureByGuid;
  String? inAttnColor;     // ← NEW
  String? outAttnColor;    // ← NEW

  EmpHistoryData({
    this.inTime,
    this.outTime,
    this.inLatAdd,
    this.inLonAdd,
    this.outLatAdd,
    this.outLonAdd,
    this.inLocAddInfo,
    this.locationFlag,
    this.outLocAddInfo,
    this.attCaptureByGuid,
    this.inAttnColor,      // ← NEW
    this.outAttnColor,     // ← NEW
  });

  factory EmpHistoryData.fromJson(Map<String, dynamic> json) {
    return EmpHistoryData(
      inTime: json['inTime'],
      outTime: json['outTime'],
      inLatAdd: json['inLatAdd']?.toString(),
      inLonAdd: json['inLonAdd']?.toString(),
      outLatAdd: json['outLatAdd']?.toString(),
      outLonAdd: json['outLonAdd']?.toString(),
      inLocAddInfo: json['inLocAddInfo']?.toString(),
      locationFlag: json['locationFlag']?.toString(),
      outLocAddInfo: json['outLocAddInfo'],
      attCaptureByGuid: json['attCaptureByGuid'],
      inAttnColor: json['inAttnColor'],      // ← NEW
      outAttnColor: json['outAttnColor'],    // ← NEW
    );
  }

  Map<String, dynamic> toJson() => {
    'inTime': inTime,
    'outTime': outTime,
    'inLatAdd': inLatAdd,
    'inLonAdd': inLonAdd,
    'outLatAdd': outLatAdd,
    'outLonAdd': outLonAdd,
    'inLocAddInfo': inLocAddInfo,
    'locationFlag': locationFlag,
    'outLocAddInfo': outLocAddInfo,
    'attCaptureByGuid': attCaptureByGuid,
    'inAttnColor': inAttnColor,       // ← NEW
    'outAttnColor': outAttnColor,     // ← NEW
  };
}


