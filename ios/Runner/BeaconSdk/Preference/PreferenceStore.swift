import Foundation

class PreferenceStore {

  private let defaults = UserDefaults.standard

  private let KEY_MONITORING_ENABLED = "monitoring_enabled"
  private let KEY_CONFIG = "sdk_config"
  private let KEY_TARGET_BEACONS = "target_beacons"
  private let KEY_LAST_NOTIFY_PREFIX = "last_notify_"
  
  func setMonitoringEnabled(_ enabled: Bool) {
      defaults.set(enabled, forKey: KEY_MONITORING_ENABLED)
  }

  func isMonitoringEnabled() -> Bool {
      return defaults.bool(forKey: KEY_MONITORING_ENABLED)
  }
  

  func saveConfig(_ config: BeaconConfig) {
    let configDict: [String: Any] = [
      "gatewayUrl": config.gatewayUrl,
      "dataUrl": config.dataUrl,
      "userId": config.userId,
      "rssiThreshold": config.rssiThreshold,
      "timeThreshold": config.timeThreshold,
      "scanPeriod": config.scanPeriod,
      "betweenScanPeriod": config.betweenScanPeriod,
      "notificationCooldown": config.notificationCooldown
    ]
      
    if let jsonData = try? JSONSerialization.data(withJSONObject: configDict, options: []),
      let jsonString = String(data: jsonData, encoding: .utf8) {
      defaults.set(jsonString, forKey: KEY_CONFIG)
    }
  }
  
  func getConfig() -> BeaconConfig? {
    guard let jsonString = defaults.string(forKey: KEY_CONFIG),
          let jsonData = jsonString.data(using: .utf8) else {
        return nil
      }
      
    do {
      if let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
        return BeaconConfig(
          gatewayUrl: json["gatewayUrl"] as? String ?? "",
          dataUrl: json["dataUrl"] as? String ?? "",
          userId: json["userId"] as? String ?? "",
          rssiThreshold: json["rssiThreshold"] as? Int ?? -85,
          timeThreshold: json["timeThreshold"] as? Int ?? 2,
          scanPeriod: json["scanPeriod"] as? Int ?? 1100,
          betweenScanPeriod: json["betweenScanPeriod"] as? Int ?? 5000,
          notificationCooldown: json["notificationCooldown"] as? Int ?? 60000
        )
      }
    } catch {
      Logger.e("Failed to parse saved config", error)
    }
    return nil
  }

  func saveTargets(_ targets: [String: String]) {
    let jsonArray = targets.map { (mac, name) -> [String: String] in
      return ["mac": mac, "name": name]
    }
    
    if let jsonData = try? JSONSerialization.data(withJSONObject: jsonArray, options: []),
      let jsonString = String(data: jsonData, encoding: .utf8) {
      defaults.set(jsonString, forKey: KEY_TARGET_BEACONS)
    }
  }
  
  func getTargetBeacons() -> [String: String] {
      guard let jsonString = defaults.string(forKey: KEY_TARGET_BEACONS),
            let jsonData = jsonString.data(using: .utf8) else {
          return [:]
      }
      
      var targets: [String: String] = [:]
      
      do {
        if let jsonArray = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: String]] {
        for obj in jsonArray {
          if let mac = obj["mac"], let name = obj["name"] {
              targets[mac] = name
            }
          }
        }
      } catch {
        Logger.e("Failed to parse target beacons", error)
      }
      
      return targets
  }
  
  func removeTargets() {
    defaults.removeObject(forKey: KEY_TARGET_BEACONS)
  }

  func getLastNotification(mac: String) -> Int64 {
    let val = defaults.object(forKey: KEY_LAST_NOTIFY_PREFIX + mac) as? Int64
    return val ?? 0
  }

  func setLastNotification(mac: String, timestamp: Int64) {
    defaults.set(timestamp, forKey: KEY_LAST_NOTIFY_PREFIX + mac)
  }
  
  func clear(mac: String) {
    defaults.removeObject(forKey: KEY_LAST_NOTIFY_PREFIX + mac)
  }

  func clearAll() {
    if let bundleID = Bundle.main.bundleIdentifier {
      defaults.removePersistentDomain(forName: bundleID)
    }
  }
}