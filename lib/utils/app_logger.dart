import 'package:flutter/material.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  final ValueNotifier<List<String>> logsNotifier = ValueNotifier([]);
  
  // Maximum logs to keep
  static const int maxLogs = 200;

  void addLog(String message) {
    String fullLog;
    if (message.startsWith('[')) {
      fullLog = message;
    } else {
      String timestamp = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}";
      fullLog = "[$timestamp] $message";
    }
    
    List<String> currentLogs = List.from(logsNotifier.value);
    currentLogs.insert(0, fullLog);
    
    while (currentLogs.length > maxLogs) {
      currentLogs.removeLast();
    }
    
    logsNotifier.value = currentLogs;    
    print(fullLog);
  }
  
  void clear() {
    logsNotifier.value = [];
    addLog("🗑️ Logs cleared");
  }
  
  List<String> getLogs() {
    return List.from(logsNotifier.value);
  }
  
  List<String> getLogsBySource(String source) {
    return logsNotifier.value.where((log) => log.contains('[$source]')).toList();
  }
}
