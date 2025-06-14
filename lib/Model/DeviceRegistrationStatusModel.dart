class DeviceRegistrationStatus {
  String status;
  String message;
  EmployeeXML employeeXML;

  DeviceRegistrationStatus({
    required this.status,
    required this.message,
    required this.employeeXML,
  });

  // Factory constructor to create an instance from JSON
  factory DeviceRegistrationStatus.fromJson(Map<String, dynamic> json) {
    return DeviceRegistrationStatus(
      status: json['status'],
      message: json['message'],
      employeeXML: EmployeeXML.fromJson(json['employeeXML']),
    );
  }

  // Method to convert the instance back to JSON
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'employeeXML': employeeXML.toJson(),
    };
  }
}

class EmployeeXML {
  String info;
  String email;
  int mobile;
  int empCode;
  String empGuid;
  String empName;
  bool deviceBlocked;
  String empDeviceGuid;
  bool devRegApproved;
  String empDesignation;

  EmployeeXML({
    required this.info,
    required this.email,
    required this.mobile,
    required this.empCode,
    required this.empGuid,
    required this.empName,
    required this.deviceBlocked,
    required this.empDeviceGuid,
    required this.devRegApproved,
    required this.empDesignation,
  });

  // Factory constructor to create an instance from JSON
  factory EmployeeXML.fromJson(Map<String, dynamic> json) {
    return EmployeeXML(
      info: json['info'],
      email: json['email'],
      mobile: json['mobile'],
      empCode: json['empCode'],
      empGuid: json['empGuid'],
      empName: json['empName'],
      deviceBlocked: json['deviceBlocked'],
      empDeviceGuid: json['empDeviceGuid'],
      devRegApproved: json['devRegApproved'],
      empDesignation: json['empDesignation'],
    );
  }

  // Method to convert the instance back to JSON
  Map<String, dynamic> toJson() {
    return {
      'info': info,
      'email': email,
      'mobile': mobile,
      'empCode': empCode,
      'empGuid': empGuid,
      'empName': empName,
      'deviceBlocked': deviceBlocked,
      'empDeviceGuid': empDeviceGuid,
      'devRegApproved': devRegApproved,
      'empDesignation': empDesignation,
    };
  }
}
