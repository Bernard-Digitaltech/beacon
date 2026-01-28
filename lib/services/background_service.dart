import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

Future<void> initializeNotificationChannels() async {
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'test_channel',
            'Test Notifications',
            importance: Importance.high,
            description: 'Channel for testing notifications via NotificationDebugger',
          ),
        );
  }

  print('📢 [BG] Test notification channel initialized');
  print('📢 [BG] Main channels created by native code (BeaconApplication.kt)');
}