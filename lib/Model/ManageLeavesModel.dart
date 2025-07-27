class LeaveResponse {
  final String msg;
  final int code;
  final List<LeavesModel> data;

  LeaveResponse({
    required this.msg,
    required this.code,
    required this.data,
  });

  factory LeaveResponse.fromJson(Map<String, dynamic> json) {
    return LeaveResponse(
      msg: json['msg'] ?? '',
      code: json['code'] ?? 0,
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => LeavesModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'msg': msg,
      'code': code,
      'data': data.map((e) => e.toJson()).toList(),
    };
  }
}

class LeavesModel {
  final String date;
  final String type;
  final String color;
  final String? remark;
  final String? subType;
  final String markedBy;

  LeavesModel({
    required this.date,
    required this.type,
    required this.color,
    this.remark,
    this.subType,
    required this.markedBy,
  });

  factory LeavesModel.fromJson(Map<String, dynamic> json) {
    return LeavesModel(
      date: json['date'] ?? '',
      type: json['type'] ?? '',
      color: json['color'] ?? '',
      remark: json['remark'],
      subType: json['sub_type'],
      markedBy: json['marked_by'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'type': type,
      'color': color,
      'remark': remark,
      'sub_type': subType,
      'marked_by': markedBy,
    };
  }
}
