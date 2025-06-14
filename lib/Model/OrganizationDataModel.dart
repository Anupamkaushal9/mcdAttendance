class OrgListResponse {
  final String status;
  final OrgList orgList;

  OrgListResponse({
    required this.status,
    required this.orgList,
  });

  // Factory method to create an OrgListResponse from JSON
  factory OrgListResponse.fromJson(Map<String, dynamic> json) {
    return OrgListResponse(
      status: json['status'],
      orgList: OrgList.fromJson(json['orgList']),
    );
  }
}

class OrgList {
  final List<OrgData> org;

  OrgList({
    required this.org,
  });

  // Factory method to create an OrgList from JSON
  factory OrgList.fromJson(Map<String, dynamic> json) {
    var orgListJson = json['org'] as List;
    List<OrgData> orgList = orgListJson.map((orgJson) => OrgData.fromJson(orgJson)).toList();

    return OrgList(
      org: orgList,
    );
  }
}

class OrgData {
  final String code;
  final String name;
  final String orgGuid;
  final String designationGuid;
  final String designationName;
  final String orgUnitBasicGuid;

  OrgData({
    required this.code,
    required this.name,
    required this.orgGuid,
    required this.designationGuid,
    required this.designationName,
    required this.orgUnitBasicGuid,
  });

  // Factory method to create an Org from JSON
  factory OrgData.fromJson(Map<String, dynamic> json) {
    return OrgData(
      code: json['code'],
      name: json['name'],
      orgGuid: json['orgGuid'],
      designationGuid: json['designationguid'],
      designationName: json['designationname'],
      orgUnitBasicGuid: json['orgUnitBasicGuid'],
    );
  }
}
