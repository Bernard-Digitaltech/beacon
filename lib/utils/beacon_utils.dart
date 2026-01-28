import 'package:flutter/material.dart';
import 'dart:math';

class BeaconUtils {
  static double calculateDistance(int rssi) {
    int txPower = -64;
    double n = 1.2;

    if (rssi == 0) { return -1.0; }

    // Formula: 10 ^ ((TxPower - RSSI) / (10 * n))
    double exponent = (txPower - rssi) / (10 * n);
    double distance = pow(10, exponent).toDouble();

    return distance;
  }

  static String distanceToString(double distance) {
    if (distance < 0) return "Unknown";
    if (distance < 1.0) {
      return "${(distance * 100).toStringAsFixed(0)} cm";
    } else {
      return "${distance.toStringAsFixed(2)} m";
    }
  }

  static String getSignalStrength(int rssi) {
    if (rssi >= -60) return '📶 Excellent';
    if (rssi >= -70) return '📶 Good';
    if (rssi >= -80) return '📶 Fair';
    return '📶 Weak';
  }

  static Color getSignalColor(int rssi) {
    if (rssi >= -60) return Colors.green;
    if (rssi >= -70) return Colors.lightGreen;
    if (rssi >= -80) return Colors.orange;
    return Colors.red;
  }

  static String getCompanyName(String companyId) {
    final companies = {
      '76': 'Apple, Inc.',
      '6': 'Microsoft',
      '224': 'Google',
    };
    return companies[companyId] ?? '';
  }

  static String hexToAscii(String hexString) {
    hexString = hexString.replaceAll(' ', '').toUpperCase();
    if (hexString.isEmpty || hexString.length % 2 != 0) return '';
    final result = StringBuffer();
    for (int i = 0; i < hexString.length; i += 2) {
      final hexByte = hexString.substring(i, i + 2);
      try {
        final byte = int.parse(hexByte, radix: 16);
        if (byte >= 32 && byte <= 126) {
          result.write(String.fromCharCode(byte));
        } else {
          result.write('.');
        }
      } catch (e) {
        result.write('?');
      }
    }
    return result.toString();
  }

  static Map<String, dynamic> identifyBeaconType(Map<String, dynamic> device) {
    final serviceUuids = device['serviceUuids'] as List<dynamic>? ?? [];
    final isEddystone = serviceUuids.any((uuid) => uuid.toString().toLowerCase().contains('feaa'));

    if (isEddystone) {
      final serviceData = device['serviceData'] as Map<dynamic, dynamic>? ?? {};
      for (var entry in serviceData.entries) {
        if (entry.key.toString().toLowerCase().contains('feaa')) {
          final data = entry.value.toString();
          if (data.startsWith('00')) return {'type': 'eddystone-uid', 'info': 'Eddystone-UID'};
          if (data.startsWith('10')) return {'type': 'eddystone-url', 'info': 'Eddystone-URL'};
          if (data.startsWith('20')) return {'type': 'eddystone-tlm', 'info': 'Eddystone-TLM'};
          if (data.startsWith('30')) return {'type': 'eddystone-eid', 'info': 'Eddystone-EID'};
          return {'type': 'eddystone', 'info': 'Eddystone'};
        }
      }
    }

    final manufacturerData = device['manufacturerData'] as Map<dynamic, dynamic>? ?? {};
    for (var entry in manufacturerData.entries) {
      final manufacturerId = entry.key.toString();
      final data = entry.value.toString();
      if (manufacturerId == '76' && data.length >= 40) {
        if (data.substring(0, 5).replaceAll(' ', '') == '0215') {
          return {'type': 'ibeacon', 'info': 'iBeacon (Apple)'};
        }
      }
    }

    if (manufacturerData.isNotEmpty) {
      for (var entry in manufacturerData.entries) {
        final data = entry.value.toString();
        if (data.startsWith('be ac') || data.toUpperCase().startsWith('BE AC')) {
          return {'type': 'altbeacon', 'info': 'AltBeacon'};
        }
      }
    }

    return {'type': 'unknown', 'info': 'Not a beacon'};
  }
}