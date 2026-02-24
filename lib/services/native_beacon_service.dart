import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';
class NativeBeaconService {
  static NativeBeaconService? _instance;
  static NativeBeaconService get instance =>
      _instance ??= NativeBeaconService._();
  NativeBeaconService._();

  // Platform Channels 
  static const _methodChannel = MethodChannel(
    'com.xenber.frontend_v2/beacon_bridge',
  );
  static const _eventChannel = EventChannel(
    'com.xenber.frontend_v2/beacon_events',
  );
  static const _navigationChannel = MethodChannel(
    'com.xenber.frontend_v2/navigation',
  );

  StreamSubscription? _eventSubscription;

  // Stream controllers
  final _beaconController = StreamController<Map<String, dynamic>>.broadcast();
  final _regionController = StreamController<Map<String, dynamic>>.broadcast();
  final _detectionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _debugController = StreamController<String>.broadcast();

  // Callback for notification tap
  Function(Map<String, dynamic>)? onNotificationTap;

  // Public streams
  Stream<Map<String, dynamic>> get beaconStream => _beaconController.stream;
  Stream<Map<String, dynamic>> get regionStream => _regionController.stream;
  Stream<Map<String, dynamic>> get detectionStream =>
      _detectionController.stream;
  Stream<String> get debugStream => _debugController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  String? _activeShiftStartTime;
  String? _activeShiftEndTime;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<bool> initialize() async {
    if (_isInitialized) {
      _log('⚠️ [Dart] Already initialized');
      return true;
    }

    try {
      _log('🚀 [Dart] Initializing native beacon service...');

      final result = await _methodChannel.invokeMethod('initialize');
      _log('📱 [Dart] Native: ${result['message']}');

      // REGISTER THE BACKGROUND HANDLE 
      final CallbackHandle? handle = PluginUtilities.getCallbackHandle(beaconBackgroundDispatcher);
      if (handle != null) {
        await _methodChannel.invokeMethod('registerBackgroundCallback', {
          'callbackHandle': handle.toRawHandle()
        });
        _log('✅ [Dart] Background callback registered (Handle: ${handle.toRawHandle()})');
      } else {
        _log('❌ [Dart] Failed to get background callback handle');
      }

      _startEventListening();
      _setupNavigationChannel();

      _isInitialized = true;
      _log('✅ [Dart] Native beacon service ready (5s scan, 5s cooldown)');
      return true;
    } on PlatformException catch (e) {
      _log('❌ [Dart] Platform error: ${e.message}');
      return false;
    } catch (e) {
      _log('❌ [Dart] Error: $e');
      return false;
    }
  }

  void _setupNavigationChannel() {
    _navigationChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTap') {
        final data = Map<String, dynamic>.from(call.arguments ?? {});
        _log('🔔 [Dart] Notification tap: ${data['locationName']}');

        _detectionController.add({...data, 'event': 'notificationTap'});

        onNotificationTap?.call(data);
      }
    });
  }

  // void _startEventListening() {
  //   _eventSubscription?.cancel();

  //   _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
  //     _handleNativeEvent,
  //     onError: (error) => _log('❌ [Dart] Event error: $error'),
  //   );

  //   _log('📡 [Dart] Event listener started');
  // }

  void _startEventListening() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((event) {
      final data = Map<String, dynamic>.from(event);
      _handleNativeEvent(event);
      if (data['event'] == 'log') {
        _debugController.add(data['message'] ?? '');
      } else {
        _detectionController.add(data);
      }
    });
  }

  void _handleNativeEvent(dynamic event) {
    if (event is! Map) return;

    final data = Map<String, dynamic>.from(event);
    final eventType = data['event'] as String?;

    final String sdkData = jsonEncode(data);
    _log('📥 [SDK Output Received] ($eventType): $sdkData');

    switch (eventType) {
      case 'log':
        final message = data['message'] as String? ?? '';
        _debugController.add(message);
        AppLogger().addLog(message);
        break;

      case 'regionEnter':
      case 'regionExit':
        _regionController.add(data);
        break;

      case 'beaconRanged':
        _detectionController.add(data);
        break;

      case 'beaconDetected':
        _detectionController.add(data);
        break;

      case 'spamBlocked':
      case 'monitoringStarted':
      case 'monitoringStopped':
        break;
    }
  }

  // ============================================================
  // TARGET BEACON MANAGEMENT
  // ============================================================

  Future<bool> addTargetBeacon({
    required String macAddress,
    required String locationName,
  }) async {
    try {
      await _methodChannel.invokeMethod('addTargetBeacon', {
        'macAddress': macAddress.toUpperCase(),
        'locationName': locationName,
      });
      return true;
    } on PlatformException catch (e) {
      _log('❌ [Dart] Error adding target: ${e.message}');
      return false;
    }
  }

  Future<void> addTargetBeacons(List<Map<String, String>> beacons) async {
    for (final beacon in beacons) {
      await addTargetBeacon(
        macAddress: beacon['macAddress']!,
        locationName: beacon['locationName']!,
      );
    }
  }

  // ============================================================
  // MONITORING CONTROL 
  // ============================================================

  Future<bool> startMonitoring({required String userId, required String authToken}) async {
    try {
      _log('🟢 [Dart] Starting monitoring for User: $userId');

      final Map<String, dynamic> config = {
        "userId": userId,
        "authToken": authToken, 
        //"gatewayUrl": dotenv.get('BEACON_GATEWAY_URL'),
        "dataUrl": dotenv.get('BEACON_DATA_URL'),
        "notiUrl": dotenv.get('NOTI_URL'),
        "rssiThreshold": int.parse(dotenv.get('BEACON_RSSI_THRESHOLD', fallback: '-85')),
        "timeThreshold": int.parse(dotenv.get('BEACON_TIME_THRESHOLD', fallback: '1')),
      };

      if ( config['notiUrl'].isEmpty || config['dataUrl'].isEmpty) {
        _log('❌ [Dart] BEACON_DATA_URL or NOTI_URL is missing in .env');
        return false;
      }

      await _methodChannel.invokeMethod('startMonitoring', config);
      return true;
    } on PlatformException catch (e) {
      _log('❌ [Dart] Error starting: ${e.message}');
      return false;
    }
  }

  Future<bool> stopMonitoring() async {
    try {
      await _methodChannel.invokeMethod('stopMonitoring');
      return true;
    } on PlatformException catch (e) {
      _log('❌ [Dart] Error stopping: ${e.message}');
      return false;
    }
  }

  // Future<bool> validateShift({
  //   required int shiftStartTime,
  //   required int shiftEndTime,
  //   required int bufferEarly,
  //   required int bufferLate,
  //   required String detectedTimestamp,
  // }) async {
  //   try {
  //     final result = await _methodChannel.invokeMethod('validateShift', {
  //       'shiftStartTime': shiftStartTime,
  //       'shiftEndTime': shiftEndTime,
  //       'bufferEarly': bufferEarly,
  //       'bufferLate': bufferLate,
  //       'timestamp': detectedTimestamp,
  //     });
  //     return result;
  //   } on PlatformException catch (e) {
  //     _log('❌ [Dart] Error validating shift: ${e.message}');
  //     return false;
  //   }
  // }

  // ============================================================
  // CHECK SHIFT TIME
  // ============================================================

  Future<bool> fetchAndSetBestShift({int maxRetries = 3}) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        final response = await http.get(Uri.parse(dotenv.get('SHIFT_TIME_URL', fallback: 'http://192.168.1.157:8000/api/v1/shifts')));
        if (response.statusCode == 200) {
          final List<dynamic> shifts = json.decode(response.body)['data'];
        
        final now = DateTime.now();
        final currentHour = now.hour;

        shifts.sort((a, b) {
          int hourA = int.parse(a['start_time'].split(':')[0]);
          int hourB = int.parse(b['start_time'].split(':')[0]);
          return (hourA - currentHour).abs().compareTo((hourB - currentHour).abs());
        });

        _activeShiftStartTime = shifts.first['start_time'];
        _activeShiftEndTime = shifts.first['end_time'];
        _log("Fetched closest start time $_activeShiftStartTime, end time $_activeShiftEndTime");
        return true;
      }
    } catch (e) {
      attempts ++;
      _log("❌ Shift Shift Error (Attempt $attempts/$maxRetries): $e");
      if (attempts < maxRetries) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }
    }
  }
  _log("❌ Shift Sync Error.");
  return false;
}

  /// The UI calls THIS function now
  Future<bool> isDetectionValid(int timestamp) async {
    if (_activeShiftStartTime == null || _activeShiftEndTime == null) return false;

    final startShiftMs = _calculateEpochMs(_activeShiftStartTime!);
    final endShiftMs = _calculateEpochMs(_activeShiftEndTime!);
    //final String detectedTs = timestamp?.toString() ?? "0";

    // Call the Native SDK logic
    return await _methodChannel.invokeMethod('validateShift', {
      'shiftStartTime': startShiftMs,
      'shiftEndTime': endShiftMs,
      'bufferEarlyCheckIn': 18000000, // 30 minutes
      'bufferLateCheckIn': 18000000, // 30 minutes
      'bufferEarlyCheckOut': 18000000, // 30 minutes
      'bufferLateCheckOut': 18000000, // 30 minutes
      'timestamp': timestamp,
    });
  }

  int _calculateEpochMs(String shiftTime) {
    final now = DateTime.now();
    final parts = shiftTime.split(':');

    final shiftHour = int.parse(parts[0]);
    final shiftMinute = int.parse(parts[1]);

    var shiftDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      shiftHour,
      shiftMinute,
    );

    // If shift time is ahead of now by many hours, assume it was yesterday
    if (shiftDateTime.isAfter(now) &&
        shiftDateTime.difference(now).inHours > 6) {
      shiftDateTime = shiftDateTime.subtract(const Duration(days: 1));
    }

    return shiftDateTime.millisecondsSinceEpoch;
  }

//     String? _determineClosestShift(List<dynamic> shifts) {
//     final now = DateTime.now();
//     final currentHour = now.hour;

//     for (var shift in shifts) {
//       final int startHour = int.parse(shift['start_time'].toString().split(':')[0]);
//       if ((startHour - currentHour).abs() <= 4) {
//         return shift['start_time'];
//       }
//     }
//     return shifts.isNotEmpty ? shifts[0]['start_time'] : null;
//   }

//   int _timeStringToEpochMs(String timeString) {
//     final now = DateTime.now();
//     final parts = timeString.split(':');
//     final hour = int.parse(parts[0]);
//     final minute = int.parse(parts[1]);

//     final shiftDateTime = DateTime(
//       now.year,
//       now.month,
//       now.day,
//       hour,
//       minute,
//     );

//     return shiftDateTime.millisecondsSinceEpoch;
//   }

//   Future<void> syncShiftConfiguration() async {
//     try {
//       final response = await http.get(Uri.parse(dotenv.get('SHIFT_TIME_URL', fallback: 'http://192.168.68.58:8000/api/v1/shifts')));
//       if (response.statusCode == 200) {
//         final jsonResponse = json.decode(response.body);
//         final List<dynamic> shifts = jsonResponse['data'];

//         final String? ClosestShiftStart = _determineClosestShift(shifts);

//         if (ClosestShiftStart != null) {
//           _activeShiftStartTime = ClosestShiftStart;
//           _log('✅ [Dart] Synced shift start time: $_activeShiftStartTime');
//         } else {
//           _log('⚠️ [Dart] Outside shift time.');
//         }
//       }
//     } catch (e) {
//       _log('❌ [Dart] Error syncing shift configuration: $e');
//     }
//   }



//   void shiftCheck(Map<String, dynamic> data) async {
//     if (_activeShiftStartTime == null) {
//       await syncShiftConfiguration();
//       if (_activeShiftStartTime == null) {
//         _log('⚠️ [Dart] No active shift start time after sync.');
//       return;
//     }

//     final startShiftMs = _timeStringToEpochMs(_activeShiftStartTime!);
//     final String detectedTs = data['timestamp']?.toString() ?? "0";

//     bool canCheckIn = await validateShift(
//       shiftStartTime: startShiftMs,
//       detectedTimestamp: detectedTs,
//     );

//     if (canCheckIn) {
//       AppLogger().addLog("🟢 [UI] Valid detection for shift starting $_activeShiftStartTime");
//       // Trigger UI or Notification here
//     } else {
//       AppLogger().addLog("⚠️ [UI] Ignored: Outside $_activeShiftStartTime shift window");
//     }
//   }
// }


    

  // Future<bool> isMonitoring() async {
  //   try {
  //     return await _methodChannel.invokeMethod('isMonitoring') ?? false;
  //   } catch (e) {
  //     return false;
  //   }
  // }

  //   Future<bool> isMonitoring() async {
  //   try {
  //     final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('getStatus');
  //     return result['isMonitoring'] == true;
  //   } catch (e) {
  //     return false;
  //   }
  // }

  // ============================================================
  // DATA RETRIEVAL
  // ============================================================

  // Future<List<Map<String, dynamic>>> getCollectedDetections() async {
  //   try {
  //     final result = await _methodChannel.invokeMethod(
  //       'getCollectedDetections',
  //     );
  //     final Map<String, dynamic> resultMap = Map<String, dynamic>.from(result);
  //     final detections = resultMap['detections'] as List<dynamic>? ?? [];
  //     return detections.map((d) => Map<String, dynamic>.from(d)).toList();
  //   } catch (e) {
  //     _log('❌ [Dart] Error getting detections: $e');
  //     return [];
  //   }
  // }

  // Future<void> clearCollectedDetections() async {
  //   try {
  //     await _methodChannel.invokeMethod('clearCollectedDetections');
  //   } catch (e) {
  //     _log('❌ [Dart] Error clearing: $e');
  //   }
  // }

  // ============================================================
  // BATTERY OPTIMIZATION
  // ============================================================

  // Future<bool> isBatteryOptimizationIgnored() async {
  //   try {
  //     final result = await _methodChannel.invokeMethod('getBatteryOptimizationStatus');
  //     final Map<String, dynamic> resultMap = Map<String, dynamic>.from(result);
  //     return resultMap['isDisabled'] == true;
  //   } catch (e) {
  //     return false;
  //   }
  // }

  // Future<void> requestBatteryOptimizationExemption() async {
  //   try {
  //     _log('🔋 [Dart] Requesting battery optimization exemption...');
  //     await _methodChannel.invokeMethod('requestBatteryOptimizationExemption');
  //   } catch (e) {
  //     _log('❌ [Dart] Error: $e');
  //   }
  // }

  // Future<void> openBatterySettings() async {
  //   try {
  //     await _methodChannel.invokeMethod('openBatterySettings');
  //   } catch (e) {
  //     _log('❌ [Dart] Error: $e');
  //   }
  // }

  // ============================================================
  // STATUS
  // ============================================================

  // Future<Map<String, dynamic>> getStatus() async {
  //   try {
  //     final result = await _methodChannel.invokeMethod('getStatus');
  //     return Map<String, dynamic>.from(result ?? {});
  //   } catch (e) {
  //     return {'error': e.toString()};
  //   }
  // }

  // Future<bool> ping() async {
  //   try {
  //     final result = await _methodChannel.invokeMethod('ping');
  //     return result['success'] == true;
  //   } catch (e) {
  //     return false;
  //   }
  // }

  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final fullMessage = '[$timestamp] $message';
    print(fullMessage);
    _debugController.add(fullMessage);
  }

  void dispose() {
    _eventSubscription?.cancel();
    _beaconController.close();
    _regionController.close();
    _detectionController.close();
    _debugController.close();
    _isInitialized = false;
  }
}

// ============================================================
// HEADLESS BACKGROUND DISPATCHER (Must be top-level)
// ============================================================
@pragma('vm:entry-point')
void beaconBackgroundDispatcher() async {
  // 1. Initialize Flutter bindings for the background isolate
  WidgetsFlutterBinding.ensureInitialized();

  // 2. IMPORTANT: Reload environment variables because this isolate shares NO memory with the main app!
  try {
    await dotenv.load(); 
  } catch (e) {
    print("👻 [Background] Failed to load .env: $e");
  }

  // 3. Set up the background listener channel
  const MethodChannel backgroundChannel = MethodChannel('com.xenber.frontend_v2/beacon_background');

  backgroundChannel.setMethodCallHandler((MethodCall call) async {
    if (call.method == 'onBackgroundBeaconDetected') {
      final args = Map<String, dynamic>.from(call.arguments ?? {});
      print("👻 [Background] HEADLESS DETECTED BEACON: $args");
      
      // TODO: Add your background logic here. 
      // Example: 
      // final dataUrl = dotenv.get('BEACON_DATA_URL');
      // await http.post(Uri.parse(dataUrl), body: jsonEncode(args));
    }
  });
}
