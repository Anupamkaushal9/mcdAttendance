class MeetingDataModel {
  final String id;
  final String meetingDate;
  final String meetingTime;
  final String meetingTitle;
  final String meetingDescription;

  MeetingDataModel({
    required this.id,
    required this.meetingDate,
    required this.meetingTime,
    required this.meetingTitle,
    required this.meetingDescription,
  });

  // Factory method to create a Meeting from JSON
  factory MeetingDataModel.fromJson(Map<String, dynamic> json) {
    return MeetingDataModel(
      id: json['id'],
      meetingDate: json['meeting_date'],
      meetingTime: json['meeting_time'],
      meetingTitle: json['meeting_title'],
      meetingDescription: json['meeting_description'],
    );
  }
}
