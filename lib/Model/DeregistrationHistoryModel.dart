class DeregistrationHistoryResponse {
  final String? msg;
  final int? code;
  final List<DeregistrationRecord>? data;

  DeregistrationHistoryResponse({
    this.msg,
    this.code,
    this.data,
  });

  factory DeregistrationHistoryResponse.fromJson(Map<String, dynamic> json) {
    return DeregistrationHistoryResponse(
      msg: json['msg'] as String?,
      code: json['code'] as int?,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => DeregistrationRecord.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'msg': msg,
    'code': code,
    'data': data?.map((e) => e.toJson()).toList(),
  };
}

class DeregistrationRecord {
  final String? remark;
  final String? status;
  final int? empBmid;
  final String? createdOn;

  DeregistrationRecord({
    this.remark,
    this.status,
    this.empBmid,
    this.createdOn,
  });

  factory DeregistrationRecord.fromJson(Map<String, dynamic> json) {
    return DeregistrationRecord(
      remark: json['remark'] as String?,
      status: json['status'] as String?,
      empBmid: json['emp_bmid'] as int?,
      createdOn: json['created_on'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'remark': remark,
    'status': status,
    'emp_bmid': empBmid,
    'created_on': createdOn,
  };
}