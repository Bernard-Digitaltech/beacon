import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class NotificationDebugger extends StatefulWidget {
  const NotificationDebugger({super.key});

  @override
  State<NotificationDebugger> createState() => _NotificationDebuggerState();
}

class _NotificationDebuggerState extends State<NotificationDebugger> {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  List<Map<String, dynamic>> _notificationHistory = [];
  bool _isInitialized = false;
  String _permissionStatus = "Checking...";
  int _testNotifCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadNotificationHistory();
    _checkPermissions();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    final bool? result = await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print("🔔 Notification clicked: ${response.payload}");
        _addToHistory("Clicked", response.payload ?? "No payload");
      },
    );

    setState(() {
      _isInitialized = result ?? false;
    });
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.areNotificationsEnabled();
        
        setState(() {
          _permissionStatus = granted == true ? "✅ Granted" : "❌ Denied";
        });

        if (granted == false) {
          // Request permission
          final bool? requestResult = await androidImplementation.requestNotificationsPermission();
          setState(() {
            _permissionStatus = requestResult == true ? "✅ Granted" : "❌ Denied";
          });
        }
      }
    }
  }

  Future<void> _loadNotificationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> history = [];
    
    // Get all keys that match notification history pattern
    for (String key in prefs.getKeys()) {
      if (key.startsWith('notif_history_')) {
        String deviceId = key.replaceFirst('notif_history_', '');
        List<String>? times = prefs.getStringList(key);
        if (times != null) {
          for (String time in times) {
            history.add({
              'device': deviceId,
              'time': time,
            });
          }
        }
      }
    }

    setState(() {
      _notificationHistory = history;
    });
  }

  void _addToHistory(String type, String message) {
    setState(() {
      _notificationHistory.insert(0, {
        'type': type,
        'message': message,
        'time': DateTime.now().toIso8601String(),
      });
      if (_notificationHistory.length > 20) {
        _notificationHistory.removeLast();
      }
    });
  }

  Future<void> _testNotification() async {
    _testNotifCount++;
    int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    
    String timestamp = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}";
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Channel for testing notifications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Test Alert',
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      channelShowBadge: true,
      onlyAlertOnce: false, // Important for multiple notifications
      autoCancel: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      notificationId,
      'Test Notification #$_testNotifCount [$timestamp]',
      'ID: $notificationId - This is test notification number $_testNotifCount',
      platformChannelSpecifics,
      payload: 'test:$_testNotifCount',
    );

    _addToHistory("Sent", "Test #$_testNotifCount with ID: $notificationId");
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Test notification #$_testNotifCount sent! ID: $notificationId'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _clearAllNotifications() async {
    await _notifications.cancelAll();
    _addToHistory("Action", "Cleared all notifications");
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications cleared'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Clear all notification history keys
    for (String key in prefs.getKeys()) {
      if (key.startsWith('notif_history_') || key.startsWith('last_notif_')) {
        await prefs.remove(key);
      }
    }

    setState(() {
      _notificationHistory.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('History cleared'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _getActiveNotifications() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final List<ActiveNotification>? activeNotifications =
            await androidImplementation.getActiveNotifications();
        
        if (activeNotifications != null) {
          _addToHistory("Check", "Active notifications: ${activeNotifications.length}");
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Active Notifications'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: activeNotifications.map((notif) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${notif.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Title: ${notif.title ?? "No title"}'),
                          Text('Body: ${notif.body ?? "No body"}'),
                          if (notif.channelId != null) Text('Channel: ${notif.channelId}'),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debugger'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotificationHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Initialized: ${_isInitialized ? "✅" : "❌"}'),
                    Text('Permission: $_permissionStatus'),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Test Count: $_testNotifCount', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _testNotification,
                  icon: const Icon(Icons.notification_add),
                  label: const Text('Test Notif'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _getActiveNotifications,
                  icon: const Icon(Icons.list),
                  label: const Text('Check Active'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _clearAllNotifications,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Clear History'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),

          // History List
          Expanded(
            child: Container(
              color: Colors.grey.shade100,
              child: _notificationHistory.isEmpty
                  ? const Center(child: Text('No notification history'))
                  : ListView.builder(
                      itemCount: _notificationHistory.length,
                      itemBuilder: (context, index) {
                        final item = _notificationHistory[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getColorForType(item['type'] ?? item['device']),
                              child: Text(
                                (item['type'] ?? 'H')[0],
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(item['message'] ?? item['device'] ?? 'Unknown'),
                            subtitle: Text(
                              _formatTime(item['time']),
                              style: const TextStyle(fontSize: 11),
                            ),
                            dense: true,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'sent':
        return Colors.green;
      case 'clicked':
        return Colors.blue;
      case 'action':
        return Colors.orange;
      case 'check':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return 'Unknown time';
    try {
      final time = DateTime.parse(timeStr);
      return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}";
    } catch (e) {
      return timeStr;
    }
  }
}