class TransferHistoryResponse {
  final String? msg;
  final int? code;
  final List<TransferRecord>? data;

  TransferHistoryResponse({
    this.msg,
    this.code,
    this.data,
  });

  factory TransferHistoryResponse.fromJson(Map<String, dynamic> json) {
    return TransferHistoryResponse(
      msg: json['msg'] as String?,
      code: json['code'] as int?,
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => TransferRecord.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'msg': msg,
    'code': code,
    'data': data?.map((e) => e.toJson()).toList(),
  };
}

class TransferRecord {
  final String? createdOn;
  final String? transferType;
  final String? transferStatus;
  final String? transferCurrentZone;
  final String? transferRequestedZone;

  TransferRecord({
    this.createdOn,
    this.transferType,
    this.transferStatus,
    this.transferCurrentZone,
    this.transferRequestedZone,
  });

  factory TransferRecord.fromJson(Map<String, dynamic> json) {
    return TransferRecord(
      createdOn: json['created_on'] as String?,
      transferType: json['transfer_type'] as String?,
      transferStatus: json['transfer_status'] as String?,
      transferCurrentZone: json['transfer_current_zone'] as String?,
      transferRequestedZone: json['transfer_requested_zone'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'created_on': createdOn,
    'transfer_type': transferType,
    'transfer_status': transferStatus,
    'transfer_current_zone': transferCurrentZone,
    'transfer_requested_zone': transferRequestedZone,
  };
}