class SupervisorEmployeeModel {
  final String? email;
  final String? inTime;
  final int? mobile;
  final int? empCode;
  final String? empGuid;
  final String? empName;
  final String? outTime;
  final int? postCode;
  final String? postName;
  final String? empDesignation;
  final String? markingAbbreviation;
  final String? orgUnitBasicInfoGuid;

  SupervisorEmployeeModel({
    required this.email,
    required this.inTime,
    required this.mobile,
    required this.empCode,
    required this.empGuid,
    required this.empName,
    required this.outTime,
    required this.postCode,
    required this.postName,
    required this.empDesignation,
    required this.markingAbbreviation,
    required this.orgUnitBasicInfoGuid,
  });

  factory SupervisorEmployeeModel.fromJson(Map<String, dynamic> json) {
    return SupervisorEmployeeModel(
      email: json['email']??'',
      inTime: json['inTime']??'',
      mobile: json['mobile']??0,
      empCode: json['empCode']??0,
      empGuid: json['empGuid']??'',
      empName: json['empName']??'',
      outTime: json['outTime']??'',
      postCode: json['postCode']??0,
      postName: json['postName']??'',
      empDesignation: json['empDesignation']??'',
      markingAbbreviation: json['markingAbbreviation']??'',
      orgUnitBasicInfoGuid: json['orgUnitBasicInfoGuid']??'',
    );
  }
}
