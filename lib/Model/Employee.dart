class Employee {
  String? status;
  List<EmpData>? empData;

  Employee({this.status, this.empData});

  factory Employee.fromJson(Map<String, dynamic> json) {

    List<EmpData> empData = [];
    var order = (json['employeeXML'] as List?);

    if (order!.isEmpty) {
      empData = [];
    } else {
      empData = order.map((data) => EmpData.fromJson(data)).toList();
    }
    return Employee(
      status : json['status'],
      empData: empData,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'emp_data': empData,
  };
}

class EmpData {
  String? info;
  String? email;
  String? mobile;
  String? empId;
  String? empCode;
  String? empGuid;
  String? empName;
  String? loginId;
  String? deviceId;
  String? empDesignation;

  EmpData({this.info, this.email, this.mobile, this.empId, this.empCode, this.empGuid,
    this.empName, this.loginId, this.deviceId, this.empDesignation});

  factory EmpData.fromJson(Map<String, dynamic> json) {
    return EmpData(
      info: json['info'],
      email: json['email'],
      mobile: json['mobile'].toString(),
      empId: json['empId'].toString(),
      empCode: json['empCode'].toString(),
      empGuid: json['empGuid'],
      empName: json['empName'],
      loginId: json['loginId'].toString(),
      deviceId: json['deviceId'],
      empDesignation: json['empDesignation'],
    );
  }

  Map<String, dynamic> toJson() => {
    'info': info,
    'email': email,
    'mobile': mobile,
    'empCode': empCode,
    'empGuid': empGuid,
    'empName': empName,
    'loginId': loginId,
    'deviceId': deviceId,
    'empDesignation': empDesignation,
  };
}

