import Foundation
import CoreLocation
import UIKit

class BeaconRegionMonitor: NSObject, CLLocationManagerDelegate, DetectionEngineDelegate {

  private let prefs: PreferenceStore
  private let lifecycle: BeaconLifecycle
  private let watchdog: BeaconWatchdog
  private let flutterBridge: FlutterBridge

  private let gatewayClient = GatewayClient()

  private var detectionEngine: DetectionEngine!
  private var locationManager: CLLocationManager?
  private var monitoredRegions: [CLBeaconRegion] = []
  private var targetBeacons: [String: String] = [:]

  private var config: BeaconConfig?
  private var isMonitoring = false
  private var withinShift = false
  
  init(prefs: PreferenceStore, 
      lifecycle: BeaconLifecycle, 
      watchdog: BeaconWatchdog, 
      flutterBridge: FlutterBridge) {
    self.prefs = prefs
    self.lifecycle = lifecycle
    self.watchdog = watchdog
    self.flutterBridge = flutterBridge
    super.init()

    self.detectionEngine = DetectionEngine(delegate: self)

    self.watchdog.onTimeout = { [weak self] in 
      Logger.e("Watchdog triggered restart.")
      self?.restartMonitoring()
    }
  }

  func applyConfig(_ config: BeaconConfig) {
    self.config = config
    gatewayClient.configure(config)
    detectionEngine.configure(config)

    Logger.i("BeaconMonitor: Config applied")
    getTargetFromServer()
  }

  func addTarget(mac: String, name: String) {
    let normalizedMAC = mac.uppercased()
    targetBeacons[normalizedMAC] = name

    prefs.saveTargets(targetBeacons)
    Logger.i("Target added: \(normalizedMAC) (\(name))")
  }

  func clearTargets() {
    stop()
    targetBeacons.removeAll()
    Logger.i("All target beacons cleared")
  }

  func start() {
    guard let config = config else {
      Logger.e("Cannot start: Config not applied")
      return
    }
        
    if isMonitoring {
      Logger.i("Already monitoring")
      return
    }

    if targetBeacons.isEmpty {
      Logger.i("No target beacons configured, fetching from server...")
      getTargetFromServer()
      return
    }

    if locationManager == nil {
      locationManager = CLLocationManager()
      locationManager?.delegate = self
      locationManager?.allowsBackgroundLocationUpdates = true
      locationManager?.pausesLocationUpdatesAutomatically = false
    }

    Logger.i("Starting iOS monitoring...")

    monitoredRegions = targetBeacons.compactMap{(uuidStr, name) -> CLBeaconRegion? in 
      guard let uuid = UUID(uuidString: uuidStr) else {return nil}
      let constraint = CLBeaconIdentityConstraint(uuid: uuid)
      let region = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: name)
      region.notifyOnEntry = true
      region.notifyOnExit = true
      region.notifyEntryStateOnDisplay = true
      return region
      }

    for region in monitoredRegions {
      locationManager?.startMonitoring(for: region)
      locationManager?.startRangingBeacons(satisfying: region.beaconIdentityConstraint)
    }

    isMonitoring = true
    watchdog.start()

    sendEvent("monitoringStarted", data: ["targetCount": targetBeacons.count])
    gatewayClient.sendEvent("SCAN_STARTED", data: [
      "device_model": UIDevice.current.model,
      "os_version": UIDevice.current.systemVersion
    ])
  }

  func stop() {
    if !isMonitoring { return }
        
    Logger.i("Stopping monitoring...")
    
    for region in monitoredRegions {
      locationManager?.stopMonitoring(for: region)
      locationManager?.stopRangingBeacons(satisfying: region.beaconIdentityConstraint)
    }
    
    watchdog.stop()
    isMonitoring = false
    
    sendEvent("monitoringStopped")
    gatewayClient.sendEvent("SCAN_STOPPED", data: [
      "device_model": UIDevice.current.model,
      "os_version": UIDevice.current.systemVersion
    ])
  }

  private func restartMonitoring() {
    if isMonitoring {
      stop()
      start()
    }
  }

  func checkShift(shiftStartTime: Double, shiftEndTime: Double, timestamp: Double, bufferEarlyIn: Double, bufferLateIn: Double, bufferEarlyOut: Double, bufferLateOut: Double) -> Bool {
    let result = detectionEngine.isWithinShift(
      start: shiftStartTime, end: shiftEndTime, now: timestamp,
      earlyIn: bufferEarlyIn, lateIn: bufferLateIn,
      earlyOut: bufferEarlyOut, lateOut: bufferLateOut
    )
    
    self.withinShift = result
    Logger.i("Shift check result: \(withinShift)")
    return withinShift
  }

  private func getTargetFromServer() {
    gatewayClient.fetchBeacons{[weak self] serverBeacons in
      guard let self = self else {return}
      
      if !serverBeacons.isEmpty {
        self.targetBeacons = serverBeacons
        Logger.i("Fetched \(serverBeacons.count) beacon targets from server")

        if !self.isMonitoring {
          self.start()
        }
      } else {
        Logger.i("Server returned empty")
      }
    }
  }

  //--- CLLocationManagerDelegate (Check Region, Ranging, Process Detected ---//
  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    Logger.i("Entered region: \(region.identifier)")

    if let beaconRegion = region as? CLBeaconRegion {
      manager.startRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
    }

    sendEvent("regionEnter", data:["regionId": region.identifier])
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    Logger.i("Exited region: \(region.identifier)")

    if let beaconRegion = region as? CLBeaconRegion {
      manager.stopRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
    }

    sendEvent("regionExit", data:["regionId": region.identifier])
  }

  func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying constraint: CLBeaconIdentityConstraint){
    watchdog.notifyScan()
    if beacons.isEmpty {return}

    for beacon in beacons {
      let mac = beacon.uuid.uuidString
      let name = targetBeacons[mac] ?? "Unknown"
      let rssi = beacon.rssi

      detectionEngine.processBeacon(
        mac: mac, 
        locationName: name, 
        rssi: rssi, 
        isBackground: !lifecycle.isForeground,
        battery: nil
      )
    }
  }

  func onBeaconRanged (mac: String, locationName: String, rssi: Int, avgRssi: Int, timestamp: Int64, isBackground: Bool, battery: Int?) {
    sendEvent("beaconRanged", data:[
      "mac": mac,
      "locationName": locationName,
      "rssi": rssi,
      "avgRssi": avgRssi, 
      "timestamp": timestamp,
      "battery": battery ?? -1
    ])
  }

  func onBeaconDetected(mac: String, locationName: String, avgRssi: Int, timestamp: Int64, battery: Int?) {
    processDetection(mac: mac, name: locationName, rssi: avgRssi)
  }

  func onBeaconLost(mac: String) {
    sendEvent("beaconLost", data: ["mac": mac])
  }

  private func processDetection(mac: String, name: String, rssi: Int) {
    guard withinShift else {
      Logger.d("Detection ignored: Outside shift")
      return
    }

    let now = Int(Date().timeIntervalSince1970 * 1000)
    let lastNotif = prefs.getLastNotification(mac: mac)
    let timeDiff = now - Int(lastNotif)
    let cooldown = config?.notificationCooldown ?? 0
    
    if timeDiff < cooldown {
      return 
    }

    gatewayClient.sendDetection(mac: mac, rssi: rssi, timestamp: now) { [weak self] (response: [String: Any] )in 

      if let shouldNotify = response["trigger_noti"] as? Bool, shouldNotify {
        self?.triggerLocalNotification(title: "Beacon Detected", body: "You are near \(name)")
        self?.prefs.setLastNotification(mac: mac, timestamp: Int64(now))
        self?.sendEvent("beaconDetected", data: [
          "mac": mac,
          "locationName": name,
          "rssi": rssi,
          "timestamp": now
        ])
      }
    }
  }

  private func sendEvent(_ eventName: String, data: [String: Any] = [:]) {
    var payload = data
    payload["event"] = eventName
    flutterBridge.send(payload)
  }

  private func triggerLocalNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }

  func getStatus() -> [String: Any] {
    return [
      "isMonitoring": isMonitoring,
      "targetCount": targetBeacons.count,
      "userId": config?.userId ?? "none"
    ]
  }
}