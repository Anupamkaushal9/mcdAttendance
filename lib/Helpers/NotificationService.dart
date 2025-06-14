import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mcd_attendance/Screens/AvailableMeetingScreen.dart';
import 'package:timezone/timezone.dart' as tz;

import '../main.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static Map<String, List<int>> payloadNotificationMap = {};

  // Method that listens for the tap on the notification
  static Future<void> onDidReceiveNotification(NotificationResponse notificationResponse) async {
    print("Notification tapped");

    String? payload = notificationResponse.payload;  // Get the payload (e.g., meeting ID)

    if (payload != null) {
      // Assuming payload is a meeting ID or name, you can navigate accordingly
      Navigator.push(
        navigatorKey.currentContext!,  // Use the global navigator key for navigation
        MaterialPageRoute(
          builder: (context) => AvailableMeetingScreen(payLoad: payload),  // Pass the payload to the details screen
        ),
      );
    }
  }

  // Initialize notification plugin and handle permissions
  static Future<void> init() async {
    const AndroidInitializationSettings androidInitializationSettings =
    AndroidInitializationSettings("@mipmap/ic_launcher");
    const DarwinInitializationSettings iOSInitializationSettings = DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iOSInitializationSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotification,
      onDidReceiveBackgroundNotificationResponse: onDidReceiveNotification,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Show an instant notification (useful for notifications you want to trigger immediately)
  static Future<void> showInstantNotification(String title, String body) async {
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_notification_channel_id',
          'Instant Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails());

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'instant_notification',
    );
  }

  // Schedule a notification for a specific time
  static Future<void> scheduleNotification(int id, String title, String body, DateTime scheduledTime, String payload) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Reminder Channel',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      androidScheduleMode: AndroidScheduleMode.exact,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,  // Adding payload here
    );

    // Save the notification ID under the payload (meetingId) in the map
    if (payloadNotificationMap.containsKey(payload)) {
    payloadNotificationMap[payload]?.add(id);
    }
    else {
    payloadNotificationMap[payload] = [id];
    }
  }

  // Cancel all notifications associated with a specific payload (meetingId)
  static Future<void> cancelNotifications(String payload) async {
    if (payloadNotificationMap.containsKey(payload)) {
      List<int> notificationIds = payloadNotificationMap[payload]!;

      for (int notificationId in notificationIds) {
        await flutterLocalNotificationsPlugin.cancel(notificationId);
        print("Cancelled notification with ID: $notificationId for payload: $payload");
      }

      // Remove the entry from the map after cancellation
      payloadNotificationMap.remove(payload);
    }
    else {
      print("No notifications found for payload: $payload");
    }
  }
}
