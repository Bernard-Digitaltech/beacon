import Foundation
import UserNotifications
import UIKit

class NotificationFactory: NSObject {
  static let shared = NotificationFactory()
  private override init() {
    super.init()
  }

  func requestPermission() {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options:[.alert, .sound, .badge]) {granted, error in
      if let error = error {
        Logger.e("Notification permission error", error)
      } else if granted {
        Logger.i("Notification permission granted")
      } 
    }
  }

  func showInternalNotification(mac: String, params:[String: Any]) {

    let locationName = params["loc"] as? String ?? "Unknown Location"
    let shiftName = params["shift"] as? String ?? "your shift"
    let rssi = params["rssi"] as? Int ?? 0
    let timestamp = params["timestamp"] as? Int64 ?? 0

    let content = UNMutableNotificationContent()
    content.title = " Nearby: \(locationName)"
    content.body = "Tap to check-in for \(shiftName) shift"
    content.sound = .default

    content.userInfo = [
      "action": "beacon_detected",
      "mac_address": mac,
      "location_name": locationName,
      "rssi": rssi,
      "timestamp": timestamp
    ]

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

    let identifier = String(mac.hashValue)
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        Logger.e("Notification failed", error)
      } else {
        Logger.d("Notification posted for \(locationName)")
      }
    }
  }
}