package com.xenber.beaconsdk.bridge

interface EventListener {
  fun onBeaconRanged(data: Map<String, Any?>)
  fun onBeaconDetected(data: Map<String, Any?>)
  fun onBeaconLost(data: Map<String, Any?>)
  fun onMonitoringStarted(data: Map<String, Any?>)
  fun onMonitoringStopped(data: Map<String, Any?>)
  fun onRegionEnter(data: Map<String, Any?>)
  fun onRegionExit(data: Map<String, Any?>)
  fun onOutsideShiftDetection(data: Map<String, Any?>)
  // Generic fallback
  fun onEvent(event: String, data: Map<String, Any?>) {}
}