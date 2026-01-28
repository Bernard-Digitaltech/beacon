import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:location/location.dart' as loc;
import '../services/native_beacon_service.dart';
import '../utils/app_logger.dart';
import '../widgets/app_terminal.dart';
import '../widgets/beacon_card.dart';
import '../config/beacon_targets.dart';
import '../widgets/notification_debugger.dart';

class BeaconScannerPage extends StatefulWidget {
  const BeaconScannerPage({super.key});

  @override
  State<BeaconScannerPage> createState() => _BeaconScannerPageState();
}

class _BeaconScannerPageState extends State<BeaconScannerPage>
    with WidgetsBindingObserver {
  final List<Map<String, dynamic>> _discoveredBeacons = [];
  bool _nativeServiceRunning = false;

  StreamSubscription<Map<String, dynamic>>? _beaconSubscription;
  StreamSubscription<Map<String, dynamic>>? _regionSubscription;
  StreamSubscription<Map<String, dynamic>>? _detectionSubscription;

  Timer? _watchdogTimer;
  bool _showDebugInfo = false;

  bool _isLoading = true;
  bool _permissionsChecked = false;
  bool _hasAllPermissions = false;
  bool _nativeServiceInitialized = false;
  Map<String, bool> _permissionStatus = {};
  int _androidSdkVersion = 0;
  List<String> _missingPermissions = [];

  Map<String, dynamic>? _pendingDetection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLogger().addLog("🚀 [UI] Scanner page initialized");
    _startInitializationFlow();
  }

  Future<void> _startInitializationFlow() async {
    setState(() => _isLoading = true);

    try {
      await _enableSystemServices();
      await _getAndroidVersion();
      await _checkAndRequestPermissions();

      if (_hasAllPermissions) {
        await _initializeServices();
      }
    } catch (e) {
      AppLogger().addLog("❌ [UI] Initialization error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getAndroidVersion() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        _androidSdkVersion = androidInfo.version.sdkInt;
        AppLogger().addLog("📱 [UI] Android SDK: $_androidSdkVersion");
      }
    } catch (e) {
      AppLogger().addLog("⚠️ [UI] Could not get Android version: $e");
      _androidSdkVersion = 30;
    }
  }

  Future<void> _enableSystemServices() async {
    Map<String, bool> permStatus = {};
    List<String> missing = [];
    try {
      if (Platform.isAndroid) {
        var adapterState = await FlutterBluePlus.adapterState.first;
        if (adapterState == BluetoothAdapterState.off) {
          AppLogger().addLog("⚠️ [UI] Bluetooth OFF. Requesting ON...");
          try {
            await FlutterBluePlus.turnOn();
            await Future.delayed(const Duration(milliseconds: 1000));
          } catch (e) {
            AppLogger().addLog("❌ [UI] Failed to auto-on Bluetooth: $e");
          }
        } else if (Platform.isIOS) {
          _showSnackBar("Please enable Bluetooth in Settings", Colors.orange);
          try {
            var adapterState = await FlutterBluePlus.adapterState.first.timeout(
              Duration(seconds: 2),
            );
            bool bluetoothGranted =
                adapterState != BluetoothAdapterState.unauthorized;
            permStatus['Bluetooth'] = bluetoothGranted;
            if (!bluetoothGranted) missing.add('Bluetooth');
            AppLogger().addLog("   ${bluetoothGranted ? '✅' : '❌'} Bluetooth");
          } catch (e) {
            AppLogger().addLog("⚠️ Could not check Bluetooth status: $e");
            permStatus['Bluetooth'] = false;
            missing.add('Bluetooth');
          }
        }
      }
    } catch (e) {
      AppLogger().addLog("❌ [UI] Bluetooth check error: $e");
    }

    try {
      loc.Location location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        AppLogger().addLog("⚠️ [UI] GPS OFF. Requesting ON...");
        serviceEnabled = await location.requestService();
        if (serviceEnabled) {
          AppLogger().addLog("✅ [UI] GPS turned ON by user");
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          AppLogger().addLog("❌ [UI] User rejected GPS request");
        }
      }
    } catch (e) {
      AppLogger().addLog("❌ [UI] GPS check error: $e");
    }
  }

  // Future<void> _initializeServices() async {
  //   if (_nativeServiceInitialized) return;

  //   AppLogger().addLog("🔧 [UI] Initializing services...");

  //   try {
  //     final service = NativeBeaconService.instance;
  //     final initialized = await service.initialize();

  //     if (!initialized) {
  //       AppLogger().addLog("⚠️ [UI] Native service init returned false");
  //       return;
  //     }

  //     AppLogger().addLog("✅ [UI] Native service initialized");
  //     AppLogger().addLog("📋 [UI] Adding ${myBeaconList.length} target beacon(s)...");

  //     for (final beacon in myBeaconList) {
  //       await service.addTargetBeacon(
  //         macAddress: beacon.macAddress,
  //         locationName: beacon.locationName,
  //       );
  //       AppLogger().addLog("   ➕ ${beacon.locationName}");
  //     }

  //     // await service.startMonitoring(userId: userId);
  //     // AppLogger().addLog("🟢 [UI] Beacon monitoring started (5s interval, 5s cooldown)");

  //     _setupNativeServiceListeners();
  //     _startWatchdog();

  //     setState(() {
  //       _nativeServiceInitialized = true;
  //       _nativeServiceRunning = true;
  //     });

  //     await _checkNativeServiceStatus();
  //     AppLogger().addLog("✅ [UI] All services initialized!");
  //   } catch (e) {
  //     AppLogger().addLog("❌ [UI] Service initialization error: $e");
  //   }
  // }

  Future<void> _initializeServices() async {
    if (_nativeServiceInitialized) return;

    AppLogger().addLog("🔧 [UI] Initializing services...");

    try {
      final service = NativeBeaconService.instance;
      final initialized = await service.initialize();

      if (!initialized) {
        AppLogger().addLog("⚠️ [UI] Native service init returned false");
        return;
      }

      AppLogger().addLog("✅ [UI] Native bridge initialized");

      try {
        await service.fetchAndSetBestShift();
        AppLogger().addLog("✅ [UI] Best shift fetched and set");
      } catch (e) {
        AppLogger().addLog("⚠️ [UI] Shift fetch error: $e");
      }

      _setupNativeServiceListeners();

      final started = await service.startMonitoring(userId: "DemoUser01");

      if (started) {
        AppLogger().addLog("🟢 [UI] Beacon monitoring started successfully");
        setState(() {
          _nativeServiceInitialized = true;
          _nativeServiceRunning = true;
        });
      } else {
        AppLogger().addLog("❌ [UI] Failed to start monitoring");
      }

      //_startWatchdog();

      AppLogger().addLog("✅ [UI] All services initialized!");
    } catch (e) {
      AppLogger().addLog("❌ [UI] Service initialization error: $e");
    }
  }

  // Future<void> _checkNativeServiceStatus() async {
  //   try {
  //     final service = NativeBeaconService.instance;
  //     final status = await service.getStatus();
  //     setState(() {
  //       _nativeServiceRunning = status['isMonitoring'] == true;
  //     });
  //     AppLogger().addLog("📊 [UI] Native Status: Monitoring=$_nativeServiceRunning");
  //   } catch (e) {
  //     AppLogger().addLog("⚠️ [UI] Status check error: $e");
  //   }
  // }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        AppLogger().addLog("📱 [UI] App resumed");
        _recheckPermissionsOnResume();
        _checkPendingDetection();
        break;
      case AppLifecycleState.paused:
        AppLogger().addLog("📱 [UI] App paused - native continues");
        break;
      default:
        break;
    }
  }

  List<Permission> _getRequiredPermissions() {
    List<Permission> permissions = [];
    if (Platform.isAndroid) {
      if (_androidSdkVersion >= 31) {
        permissions.addAll([
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ]);
      } else {
        permissions.add(Permission.bluetooth);
      }
      permissions.addAll([Permission.location, Permission.notification]);
    } else if (Platform.isIOS) {
      permissions.addAll([
        Permission.bluetooth,
        Permission.locationWhenInUse,
        Permission.notification,
      ]);
    }
    return permissions;
  }

  Future<void> _checkAndRequestPermissions() async {
    AppLogger().addLog("🔐 [UI] Checking permissions...");
    setState(() => _permissionsChecked = false);

    final requiredPermissions = _getRequiredPermissions();
    Map<String, bool> permStatus = {};
    List<String> missing = [];

    for (var permission in requiredPermissions) {
      var status = await permission.status;
      String permName = _getPermissionDisplayName(permission);
      bool isGranted = status.isGranted;
      permStatus[permName] = isGranted;

      if (Platform.isIOS && permission == Permission.locationWhenInUse) {
        if (status == PermissionStatus.granted) {
          var alwaysStatus = await Permission.locationAlways.status;
          if (!alwaysStatus.isGranted) {
            isGranted = false;
            permName = "Location (Upgrate to Always)";
          }
        }
      }

      permStatus[permName] = isGranted;

      if (!isGranted) {
        missing.add(permName);
        AppLogger().addLog("   ❌ $permName: Not granted");
      } else {
        AppLogger().addLog("   ✅ $permName: Granted");
      }
    }

    bool allGranted = missing.isEmpty;

    if (!allGranted) {
      AppLogger().addLog(
        "📝 [UI] Requesting ${missing.length} permission(s)...",
      );
      Map<Permission, PermissionStatus> results = await requiredPermissions
          .request();

      if (Platform.isIOS) {
        var whenInUse = await Permission.locationWhenInUse.status;
        var always = await Permission.locationAlways.status;

        if (whenInUse.isGranted && !always.isGranted) {
          await Permission.locationAlways.request();
        }
      }

      missing.clear();
      for (var entry in results.entries) {
        String permName = _getPermissionDisplayName(entry.key);
        bool isGranted = entry.value.isGranted;
        permStatus[permName] = isGranted;

        if (!isGranted) {
          missing.add(permName);
          AppLogger().addLog("   ❌ $permName: Denied");
        } else {
          AppLogger().addLog("   ✅ $permName: Granted");
        }
      }
      allGranted = missing.isEmpty;
    }

    setState(() {
      _permissionsChecked = true;
      _hasAllPermissions = allGranted;
      _permissionStatus = permStatus;
      _missingPermissions = missing;
    });

    if (allGranted) {
      AppLogger().addLog("✅ [UI] All permissions granted!");
    } else {
      AppLogger().addLog("⚠️ [UI] Missing: ${missing.join(', ')}");
    }
  }

  Future<void> _recheckPermissionsOnResume() async {
    if (!_permissionsChecked) return;

    try {
      final requiredPermissions = _getRequiredPermissions();
      bool allGranted = true;

      for (var permission in requiredPermissions) {
        var status = await permission.status;
        if (!status.isGranted) {
          allGranted = false;
          break;
        }
      }

      if (allGranted && !_hasAllPermissions) {
        AppLogger().addLog("✅ [UI] Permissions now granted!");
        setState(() {
          _hasAllPermissions = true;
          _missingPermissions = [];
        });
        await _initializeServices();
      } else if (!allGranted && _hasAllPermissions) {
        AppLogger().addLog("⚠️ [UI] Permissions revoked!");
        setState(() => _hasAllPermissions = false);
      }
    } catch (e) {
      AppLogger().addLog("⚠️ [UI] Recheck error: $e");
    }
  }

  String _getPermissionDisplayName(Permission permission) {
    switch (permission) {
      case Permission.bluetooth:
        return 'Bluetooth';
      case Permission.bluetoothScan:
        return 'Nearby devices (Scan)';
      case Permission.bluetoothConnect:
        return 'Nearby devices (Connect)';
      case Permission.location:
        return 'Location';
      case Permission.locationWhenInUse:
        return 'Location (When in use)';
      case Permission.locationAlways:
        return 'Location (Always)';
      case Permission.notification:
        return 'Notifications';
      default:
        return permission.toString().replaceAll('Permission.', '');
    }
  }

  void _setupNativeServiceListeners() {
    final service = NativeBeaconService.instance;

    _beaconSubscription = service.beaconStream.listen((data) {
      _updateBeaconFromNative(data);
    });

    _regionSubscription = service.regionStream.listen((data) {
      final event = data['event'];
      if (event == 'regionEnter') {
        _showSnackBar('🟢 Entered region', Colors.green);
      } else if (event == 'regionExit') {
        _showSnackBar('🔴 Exited region', Colors.orange);
      }
    });

    _detectionSubscription = service.detectionStream.listen((data) {
      final event = data['event'];
      if (event == 'beaconRanged') {
        _onBeaconDetected(data);
        return;
      }
      if (event == 'beaconDetected') {
        final locationName = data['locationName'] ?? 'Unknown';
        _showSnackBar('🎯 Beacon detected: $locationName', Colors.blue);
      } else if (event == 'notificationTap') {
        _handleNotificationTap(data);
      }
    });

    service.onNotificationTap = (data) => _handleNotificationTap(data);
    AppLogger().addLog("📡 [UI] Native service listeners setup");
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final locationName = data['locationName'] ?? 'Unknown';
    AppLogger().addLog("🔔 [UI] Notification tap: $locationName");
    _showDetectionDetailsDialog(data);
  }

  void _checkPendingDetection() {
    if (_pendingDetection != null) {
      _showDetectionDetailsDialog(_pendingDetection!);
      _pendingDetection = null;
    }
  }

  // Future<void> _checkNativeServiceStatus() async {
  //   try {
  //     final service = NativeBeaconService.instance;
  //     final isMonitoring = await service.isMonitoring();
  //     setState(() => _nativeServiceRunning = isMonitoring);
  //   } catch (e) {
  //     AppLogger().addLog("⚠️ [UI] Status check error: $e");
  //   }
  // }

  void _updateBeaconFromNative(Map<String, dynamic> data) {
    final mac = (data['macAddress'] as String?)?.toUpperCase();
    if (mac == null) return;

    final rssi = data['avgRssi'] as int? ?? data['rssi'] as int? ?? -100;
    final locationName =
        data['locationName'] as String? ?? _getLocationName(mac);
    _updateBeaconInList(mac, rssi, locationName);
  }

  void _updateBeaconInList(String mac, int rssi, String name) {
    setState(() {
      final existingIndex = _discoveredBeacons.indexWhere(
        (b) => (b['id'] as String).toUpperCase() == mac,
      );

      final beaconData = {
        'id': mac,
        'name': _getLocationName(mac),
        'rssi': rssi,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
        'isLost': false,
      };

      if (existingIndex >= 0) {
        _discoveredBeacons[existingIndex] = beaconData;
      } else {
        _discoveredBeacons.add(beaconData);
      }
    });
  }

  String _getLocationName(String mac) {
    for (var beacon in myBeaconList) {
      if (beacon.macAddress.toUpperCase() == mac.toUpperCase()) {
        return beacon.locationName;
      }
    }
    return 'Unknown Beacon';
  }

  void _startWatchdog() {
    _watchdogTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkForLostBeacons();
    });
  }

  void _checkForLostBeacons() {
    final now = DateTime.now().millisecondsSinceEpoch;
    const timeout = 15000; // 5s scan + 10s buffer

    setState(() {
      for (var beacon in _discoveredBeacons) {
        final lastSeen = beacon['lastSeen'] as int? ?? 0;
        if (now - lastSeen > timeout) {
          beacon['isLost'] = true;
        }
      }
    });
  }

  void _onBeaconDetected(Map<String, dynamic> data) async {
    final bool isValid = await NativeBeaconService.instance.isDetectionValid(
      data['timestamp'],
    );

    if (isValid) {
      //_showDetectionDetailsDialog(data);
      AppLogger().addLog("🟢 [UI] Detection within valid shift hours.");
      _showSnackBar('✅ Detection confirmed within shift hours', Colors.green);
    } else {
      AppLogger().addLog("⚠️ [UI] Detection ignored: Outside shift hours");
      _showSnackBar('⚠️ Outside your scheduled shift window', Colors.orange);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showDetectionDetailsDialog(Map<String, dynamic> data) {
    final locationName = data['locationName'] ?? 'Unknown';
    final macAddress = data['macAddress'] ?? 'Unknown';
    final rssi = data['rssi'] ?? data['avgRssi'] ?? 0;
    final timestamp = data['timestamp'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Beacon Detected', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Location', locationName),
            _buildDetailRow('MAC Address', macAddress),
            _buildDetailRow('Signal', '$rssi dBm'),
            _buildDetailRow('Time', _formatTimestamp(timestamp)),
            if (data['isBackground'] == true)
              _buildDetailRow('Mode', 'Background'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ready for check-in confirmation',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmCheckIn(data);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'CONFIRM CHECK-IN',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp.toString();
    }
  }

  void _confirmCheckIn(Map<String, dynamic> data) {
    final locationName = data['locationName'] ?? 'Unknown';
    AppLogger().addLog("✅ [UI] Check-in confirmed for $locationName");
    _showSnackBar('✅ Check-in confirmed!', Colors.green);
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Permissions Required',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This app needs permissions to detect beacons for attendance tracking:',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ..._missingPermissions.map((perm) => _buildPermissionItem(perm)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _androidSdkVersion >= 31
                            ? 'On Android 12+, Bluetooth permissions appear as "Nearby devices" in settings.'
                            : 'You can change permissions in app settings anytime.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('LATER', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _checkAndRequestPermissions();
              if (_hasAllPermissions) await _initializeServices();
            },
            child: const Text('TRY AGAIN'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'OPEN SETTINGS',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(String permission) {
    IconData icon;
    String description;

    if (permission.toLowerCase().contains('nearby') ||
        permission.toLowerCase().contains('bluetooth')) {
      icon = Icons.bluetooth;
      description = 'Required to scan for Bluetooth beacons';
    } else if (permission.toLowerCase().contains('location')) {
      icon = Icons.location_on;
      description = 'Required by Android for Bluetooth scanning';
    } else if (permission.toLowerCase().contains('notification')) {
      icon = Icons.notifications;
      description = 'Required for beacon detection alerts';
    } else {
      icon = Icons.security;
      description = 'Required for app functionality';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: Colors.red, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permission,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _beaconSubscription?.cancel();
    _regionSubscription?.cancel();
    _detectionSubscription?.cancel();
    _watchdogTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Initializing...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beacon Monitor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(
              _showDebugInfo ? Icons.bug_report : Icons.bug_report_outlined,
            ),
            onPressed: () async {
              setState(() => _showDebugInfo = !_showDebugInfo);
              // if (_showDebugInfo) await _checkNativeServiceStatus();
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationDebugger(),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _nativeServiceRunning
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.bluetooth_disabled,
                      size: 15,
                      color: Colors.grey,
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_permissionsChecked && !_hasAllPermissions)
            _buildPermissionWarningBanner(),
          _buildStatusHeader(),
          if (_showDebugInfo) _buildDebugPanel(),
          Expanded(
            flex: 2,
            child: _hasAllPermissions
                ? _buildBeaconList()
                : _buildPermissionRequiredScreen(),
          ),
          const Expanded(
            flex: 1,
            child: Padding(padding: EdgeInsets.all(8), child: AppTerminal()),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionWarningBanner() {
    return GestureDetector(
      onTap: _showPermissionDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.red.shade100,
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Some permissions are missing. Tap to fix.',
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.red.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    final isActive = _hasAllPermissions && _nativeServiceRunning;
    final beaconCount = _discoveredBeacons.length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: isActive ? Colors.green.shade50 : Colors.orange.shade50,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isActive ? Icons.radar : Icons.warning_amber_rounded,
              color: isActive ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'Monitoring Active' : 'Permissions Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Scan: 5s | Cooldown: 5s | Beacons: $beaconCount',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug (Android $_androidSdkVersion)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text('Permissions: ${_hasAllPermissions ? "✅" : "❌"}'),
              Text('Native: ${_nativeServiceRunning ? "✅" : "❌"}'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              // _buildDebugButton(Icons.battery_saver, 'Battery', () async {
              //   await NativeBeaconService.instance.requestBatteryOptimizationExemption();
              // }),
              _buildDebugButton(
                Icons.security,
                'Permissions',
                _showPermissionDialog,
              ),
              _buildDebugButton(Icons.refresh, 'Retry Init', () async {
                await _checkAndRequestPermissions();
                if (_hasAllPermissions) await _initializeServices();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugButton(
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 28),
      ),
    );
  }

  Widget _buildBeaconList() {
    if (_discoveredBeacons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Searching for beacons...',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Native monitoring active (5s scan, 5s cooldown)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _discoveredBeacons.length,
      itemBuilder: (ctx, i) => BeaconCard(beacon: _discoveredBeacons[i]),
    );
  }

  Widget _buildPermissionRequiredScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security, size: 64, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            const Text(
              'Permissions Required',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _androidSdkVersion >= 31
                  ? 'This app needs "Nearby devices", Location, and Notification permissions.'
                  : 'This app needs Bluetooth, Location, and Notification permissions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await _checkAndRequestPermissions();
                if (_hasAllPermissions) await _initializeServices();
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('GRANT PERMISSIONS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async => await openAppSettings(),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Open App Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
