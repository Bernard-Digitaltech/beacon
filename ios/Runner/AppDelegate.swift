import Flutter
import UIKit
import UserNotifications

@main
// @objc class AppDelegate: FlutterAppDelegate {
//   override func application(
//     _ application: UIApplication,
//     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//   ) -> Bool {
//     let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
//     let beaconRegistrar = controller.registrar(forPlugin: "com.xenber.frontend_v2/beacon_bridge")!
//     FlutterBridge.register(with: beaconRegistrar)
    
//     GeneratedPluginRegistrant.register(with: self)
//     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//   }
// }
//----//
// @objc class AppDelegate: FlutterAppDelegate {
//   override func application(
//     _ application: UIApplication,
//     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//   ) -> Bool {

//     GeneratedPluginRegistrant.register(with: self)
    
//     if let beaconRegistrar = self.registrar(forPlugin: "com.xenber.frontend_v2/beacon_bridge") {
//         FlutterBridge.register(with: beaconRegistrar)
//     }
    
//     let _ = BeaconSDK.shared 

//     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//   }
// }

@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    NSLog("✅ [AppDelegate] 1")  
    
    if let beaconRegistrar = self.registrar(forPlugin: "com.kerja101.mobileapp.beacon_bridge"){
      FlutterBridge.register(with: beaconRegistrar)
    }
    NSLog("✅ [AppDelegate] 2")  

    let _ = BeaconSDK.shared
    NSLog("✅ [AppDelegate] BeaconSDK set up")  // ✅ Use NSLog instead
    sendDebugNoti("App Booted", "iOS woke AppDelegate manually")

      if let launchOptions = launchOptions {
              NSLog("📋 [AppDelegate] Launch options: \(launchOptions)")
              
              if launchOptions.keys.contains(.location) {
                  sendDebugNoti("1: App Booted", "iOS woke AppDelegate with location key")
                  NSLog("📍 [AppDelegate] App launched from LOCATION event")
              } else {
                  NSLog("ℹ️ [AppDelegate] App launched normally (not from location)")
                  NSLog("ℹ️ [AppDelegate] Launch keys: \(launchOptions.keys)")
              }
          } else {
              NSLog("ℹ️ [AppDelegate] No launch options (normal user launch)")
          }
      // ✅ TEST: Manually trigger a beacon event after 3 seconds
//      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//          NSLog("🧪 [AppDelegate] Manually triggering beacon event")
//          
//          let testBeaconData: [String: Any?] = [
//              "event": "beaconDetected",
//              "macAddress": "TEST:MAC:ADDRESS",
//              "rssi": -65,
//              "locationName": "Test Location",
//              "timestamp": Date().timeIntervalSince1970 * 1000
//          ]
//          
//          FlutterBridge.shared.send(testBeaconData)
//      }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

func sendDebugNoti (_ title: String, _ body: String) {
  NSLog("🔔 [Debug Noti] \(title): \(body)")  // ✅ Log before sending
  
  let content = UNMutableNotificationContent()
  content.title = "[DEBUG] " + title
  content.body = body
  content.sound = nil

  let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

  UNUserNotificationCenter.current().add(request) { error in
    if let error = error {
      NSLog("❌ [Debug Noti] Failed to send: \(error)")
    } else {
      NSLog("✅ [Debug Noti] Sent successfully")
    }
  }
}
