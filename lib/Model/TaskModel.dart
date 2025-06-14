import 'dart:convert';

class TaskDataModel {
  final String id;
  final String taskTitle;
  final List<String> taskActive;
  final List<String> taskInactive;
  final String taskDeadlineDate;
  final String taskDeadlineTime;

  TaskDataModel({
    required this.id,
    required this.taskTitle,
    required this.taskActive,
    required this.taskInactive,
    required this.taskDeadlineDate,
    required this.taskDeadlineTime,
  });

  // Convert from JSON to Task
  factory TaskDataModel.fromJson(Map<String, dynamic> json) {
    return TaskDataModel(
      id: json['id'],
      taskTitle: json['task_title'],
      taskActive: List<String>.from(json['task_active']),
      taskInactive: List<String>.from(json['task_inactive']),
      taskDeadlineDate: json['task_deadline_date'],
      taskDeadlineTime: json['task_deadline_time'],
    );
  }

  // Convert Task to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_title': taskTitle,
      'task_active': taskActive,
      'task_inactive': taskInactive,
      'task_deadline_date': taskDeadlineDate,
      'task_deadline_time': taskDeadlineTime,
    };
  }
}