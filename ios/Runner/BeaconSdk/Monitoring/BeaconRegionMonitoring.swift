import Foundation
import CoreLocation
import UIKit
import Network

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

  // Network monitor for offline mode
  private let networkMonitor = NWPathMonitor()
  private var isConnected = true
  
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
    // Initialize Network Monitor
    networkMonitor.pathUpdateHandler = { [weak self] path in
        self?.isConnected = (path.status == .satisfied)
    }
    networkMonitor.start(queue: DispatchQueue.global(qos: .background))
  }

  func applyConfig(_ config: BeaconConfig) {
    self.config = config
    gatewayClient.configure(config)
    detectionEngine.configure(config)

    // Load beacons data from local storage first
    let localTargets = prefs.getTargetBeacons()
    if !localTargets.isEmpty {
        self.targetBeacons = localTargets
        Logger.i("Loaded \(localTargets.count) targets from local storage.")
    } else {
        Logger.e("Local storage empty. Waiting for server sync.")
    }

    Logger.i("BeaconMonitor: Config applied")
    getTargetFromServer()
  }

  func addTarget(uuid: String, major: Int?, minor: Int?, name: String) {
    let key = getBeaconKey(uuid: uuid, major: major, minor: minor)
    targetBeacons[key] = name

    if targetBeacons[uuid.uppercased()] == nil {
        targetBeacons[uuid.uppercased()] = "Generic Region"
    }

    prefs.saveTargets(targetBeacons)
    Logger.i("Target added: \(key) (\(name))")
  }

  func clearTargets() {
    stop()
    targetBeacons.removeAll()
    prefs.removeTargets()
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

    // 1. Group targets by UUID 
    let uniqueUUIDs = Set(targetBeacons.keys.map { key -> String in
        return key.components(separatedBy: ":")[0] 
    })

    // 2. Create ONE region per UUID
    monitoredRegions = uniqueUUIDs.compactMap{ uuidStr -> CLBeaconRegion? in 
      let cleanUUID = uuidStr.trimmingCharacters(in: .whitespacesAndNewlines)

      guard let uuid = UUID(uuidString: cleanUUID) else {
        Logger.e("Invalid UUID: \(uuidStr)")
        return nil
      }

      let constraint = CLBeaconIdentityConstraint(uuid: uuid)
      let region = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: cleanUUID)
      region.notifyOnEntry = true
      region.notifyOnExit = true
      region.notifyEntryStateOnDisplay = true

      Logger.i("Region created: \(uuid.uuidString)")
      return region
    }

    if monitoredRegions.isEmpty {
      Logger.e("No regions created")
      return
    }

    for region in monitoredRegions {
      locationManager?.startMonitoring(for: region)
      locationManager?.startRangingBeacons(satisfying: region.beaconIdentityConstraint)
      locationManager?.requestState(for: region)
    }

    isMonitoring = true
    watchdog.start()

    sendEvent("monitoringStarted", data: ["targetCount": targetBeacons.count])
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
        self.prefs.saveTargets(serverBeacons)
        Logger.i("Fetched \(serverBeacons.count) beacon targets from server")

        if !self.isMonitoring {
          self.start()
        } else {
          Logger.i("Updating active regions with new server targets")
          self.restartMonitoring()
        }
      } else {
        Logger.i("Server returned empty beacon list.")
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

      // let uuidStr = region.identifier
      // let removed = activeRegions.filter { $0.hasPrefix(uuidStr) }

      // for key in removed {
      //   activeRegions.remove(key)
      //   Logger.i("Removed beacon: \(key) (Exited Region)")
      // }
    }

    sendEvent("regionExit", data:["regionId": region.identifier])
  }

  func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying constraint: CLBeaconIdentityConstraint){
    watchdog.notifyScan()
    if beacons.isEmpty {
      Logger.i("No beacons found in region")
      return
    }

    for beacon in beacons {
      let uuid = beacon.uuid.uuidString.uppercased()
      let major = beacon.major.intValue
      let minor = beacon.minor.intValue
      let rssi = beacon.rssi

      let specificKey = getBeaconKey(uuid: uuid, major: major, minor: minor)

      let name = targetBeacons[specificKey] ?? targetBeacons[uuid] ?? "Unknown Beacon"

      Logger.i("Found beacon: \(name) | RSSI: \(rssi)")

      detectionEngine.processBeacon(
        mac: specificKey, 
        locationName: name, 
        rssi: rssi, 
        isBackground: !lifecycle.isForeground,
        battery: nil
      )
    }
  }

  //--- CLLocationManagerDelegate Debugging ---//
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Logger.e("❌ Location Manager Failed: \(error.localizedDescription)")
  }

  func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
    Logger.e("❌ Monitoring Failed for region \(region?.identifier ?? "unknown"): \(error.localizedDescription)")
  }

  func locationManager(_ manager: CLLocationManager, rangingBeaconsDidFailFor region: CLBeaconRegion, withError error: Error) {
    Logger.e("❌ Ranging Failed for region \(region.identifier): \(error.localizedDescription)")
    
    let nsError = error as NSError
    if nsError.domain == kCLErrorDomain && nsError.code == 104 {
        Logger.e("⚠️ Error 104: Ranging Unavailable. (Bluetooth might be OFF or 'Precise Location' is disabled)")
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = manager.authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }

    switch status {
    case .authorizedAlways:
        Logger.i("✅ Permission: ALWAYS")
    case .authorizedWhenInUse:
        Logger.i("⚠️ Permission: WHEN IN USE (Background detection might fail)")
    case .denied, .restricted:
        Logger.e("❌ Permission: DENIED/RESTRICTED")
    case .notDetermined:
        Logger.i("❓ Permission: NOT DETERMINED")
    default:
        Logger.i("Permission Status: \(status.rawValue)")
    }

    if #available(iOS 14.0, *) {
        switch manager.accuracyAuthorization {
        case .fullAccuracy:
            Logger.i("✅ Precise Location: ON")
        case .reducedAccuracy:
            Logger.e("❌ Precise Location: OFF (Beacons are blocked by iOS!)")
        @unknown default:
            break
        }
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

    let online = isOnline()

    if !online {
      Logger.w("Offline: Caching detection for \(mac)")
      prefs.addOfflineLog(mac: mac, timestamp: timestamp)
      sendEvent("offlineDetection", data: [
        "mac": mac,
        "locationName": locationName,
        "avgRssi": avgRssi, 
        "timestamp": timestamp,
        "battery": battery ?? -1
      ])
      triggerLocalNotification(title: "Check In", body: "You are near \(locationName)")
      return
    }

    if !withinShift {
      Logger.d("Detection ignored: Outside shift")
      sendEvent("OutsideShiftDetection", data: [
        "mac": mac,
        "locationName": locationName,
        "avgRssi": avgRssi, 
        "timestamp": timestamp,
        "battery": battery ?? -1
      ])
      return
    }
    guard let config = config else { return }
    let now = Int64(Date().timeIntervalSince1970 * 1000)
    let lastNotif = prefs.getLastNotification(mac: mac)
    let cooldown = Int64(config.notificationCooldown)
    
    if (now - lastNotif) < cooldown {
      Logger.i("💪 Cooldown active for \(locationName)")
      return 
    }

    prefs.setLastNotification(mac: mac, timestamp: now)
    
    sendEvent("beaconDetected", data: [
      "macAddress": mac,
      "locationName": locationName,
      "avgRssi": avgRssi,
      "timestamp": timestamp,
      "battery": battery ?? -1
    ])
      
    Logger.i("💪Detection event sent [\(mac)]")
      
    triggerLocalNotification(title: "Check In", body: "You are near \(locationName)")
    //processDetection(mac: mac, name: locationName, rssi: avgRssi)
  }

  func onBeaconLost(mac: String) {
    sendEvent("beaconLost", data: ["mac": mac])
  }

  private func getBeaconKey(uuid: String, major:Int?, minor: Int?) -> String {
    let u = uuid.uppercased()
    if let maj = major, let min = minor {
      return "\(u):\(maj):\(min)"
    }
    return u
  }

  // private func processDetection(mac: String, name: String, rssi: Int) {
  //   guard withinShift else {
  //     Logger.d("Detection ignored: Outside shift")
  //     return
  //   }

  //   let now = Int(Date().timeIntervalSince1970 * 1000)
  //   let lastNotif = prefs.getLastNotification(mac: mac)
  //   let timeDiff = now - Int(lastNotif)
  //   let cooldown = config?.notificationCooldown ?? 0
    
  //   if timeDiff < cooldown {
  //     return 
  //   }

  //   gatewayClient.sendDetection(mac: mac, rssi: rssi, timestamp: now) { [weak self] (response: [String: Any] )in 

  //     if let shouldNotify = response["trigger_noti"] as? Bool, shouldNotify {
  //       self?.triggerLocalNotification(title: "Beacon Detected", body: "You are near \(name)")
  //       self?.prefs.setLastNotification(mac: mac, timestamp: Int64(now))
  //       self?.sendEvent("beaconDetected", data: [
  //         "mac": mac,
  //         "locationName": name,
  //         "rssi": rssi,
  //         "timestamp": now
  //       ])
  //     }
  //   }
  // }

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

  private func isOnline() -> Bool {
    return isConnected
  }
}