class AppConfig {
  // ============================================================
  // UI SETTINGS (Flutter-side only)
  // ============================================================
  
  /// Timeout for UI scan display (minutes)
  /// After this, FlutterBluePlus stops scanning to save battery
  static const int uiScanTimeout = 30;

  /// Max log entries to keep in terminal widget
  static const int maxLogEntries = 100;
}