import Flutter
import UIKit
import UserNotifications

public class FlutterBridge: NSObject, FlutterPlugin, FlutterStreamHandler, UNUserNotificationCenterDelegate{
  
  public static let shared = FlutterBridge()
  private var eventSink: FlutterEventSink?

  private let METHOD_CHANNEL_NAME = "com.xenber.frontend_v2/beacon_bridge"
  private let EVENT_CHANNEL_NAME = "com.xenber.frontend_v2/beacon_events"

  // Plugin Registration
  public static func register(with registrar: FlutterPluginRegistrar) {
  let instance = FlutterBridge.shared
  
  let methodChannel = FlutterMethodChannel(name: instance.METHOD_CHANNEL_NAME, binaryMessenger: registrar.messenger())
  registrar.addMethodCallDelegate(instance, channel: methodChannel)
 
  let eventChannel = FlutterEventChannel(name: instance.EVENT_CHANNEL_NAME, binaryMessenger: registrar.messenger())
  eventChannel.setStreamHandler(instance)
  
  UNUserNotificationCenter.current().delegate = instance
  
  Logger.i("🔥 FlutterBridge ATTACHED (iOS)")
  }

  public func handle(_ call:FlutterMethodCall, result: @escaping FlutterResult) {
    let sdk = BeaconSDK.shared
    switch call.method {

    case "initialize":
      sdk.initialize()
      result([
        "status": "success",
        "message": "SDK core initialized"
      ])

    case "startMonitoring":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGS", message: "Arguments missing", details: nil))
        return
      }

      let config = BeaconConfig(
        //gatewayUrl: args["gatewayUrl"] as? String ?? "",
        dataUrl: args["dataUrl"] as? String ?? "",
        userId: args["userId"] as? String ?? "unknown",
        rssiThreshold: args["rssiThreshold"] as? Int ?? -85,
        timeThreshold: args["timeThreshold"] as? Int ?? 2,
        scanPeriod: args["scanPeriod"] as? Int ?? 1100,
        betweenScanPeriod: args["betweenScanPeriod"] as? Int ?? 5000,
        notificationCooldown: 60000
      )
    
    sdk.configure(config: config)
    sdk.start()
    result(true)

    case "stopMonitoring":
      sdk.stop()
      result(true)

    case "addTargetBeacon":
      guard let args = call.arguments as? [String: Any],
          let uuid = args["uuid"] as? String,
          let major = args["major"] as? Int,
          let minor = args["minor"] as? Int,
          let name = args["locationName"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "UUID, Major, Minor or Name missing", details: nil))
        return
      }
      sdk.addTarget(uuid: uuid, major: major, minor: minor, name: name)
      result(true)

    case "isMonitoring":
      let status = sdk.getStatus()
      let isMon = status["isMonitoring"] as? Bool ?? false
      result(isMon)

    case "validateShift":
      guard let args = call.arguments as? [String: Any] else {
        result(false)
        return
      }
      
      let start = (args["shiftStartTime"] as? NSNumber)?.doubleValue ?? 0
      let end = (args["shiftEndTime"] as? NSNumber)?.doubleValue ?? 0
      let bufferEarlyIn = (args["bufferEarlyCheckIn"] as? NSNumber)?.doubleValue ?? 0
      let bufferLateIn = (args["bufferLateCheckIn"] as? NSNumber)?.doubleValue ?? 0
      let bufferEarlyOut = (args["bufferEarlyCheckOut"] as? NSNumber)?.doubleValue ?? 0
      let bufferLateOut = (args["bufferLateCheckOut"] as? NSNumber)?.doubleValue ?? 0
      let timestamp = (args["timestamp"] as? NSNumber)?.doubleValue ?? 0
      
      let withinShift = sdk.checkShift(
        shiftStartTime: start,
        shiftEndTime: end,
        timestamp: timestamp,
        bufferEarlyIn: bufferEarlyIn,
        bufferLateIn: bufferLateIn,
        bufferEarlyOut: bufferEarlyOut,
        bufferLateOut: bufferLateOut
      )
      result(withinShift)
      
    case "getDiagnostic":
      let diag = sdk.getDiagnostics()
      result(diag)
    
    case "registerBackgroundCallback":
      guard let args = call.arguments as? [String: Any],
            let handle = (args["callbackHandle"] as? NSNumber)?.int64Value else {
          result(FlutterError(code: "INVALID_ARGS", message: "Callback Handle missing", details: nil))
          return
      }
        
      UserDefaults.standard.set(handle, forKey: "dispatcher_handle")
      result(true)
        
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // Event Handling (iOS -> Flutter)
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events

    BeaconSDK.shared.setEventCallback { [weak self] (data: [String: Any?]) in
      self?.send(data)
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    BeaconSDK.shared.setEventCallback(nil)
    self.eventSink = nil
    return nil
  }

  func send(_ data: [String: Any?]) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if let sink = self.eventSink {
        sink(data)
      } else {
        if let event = data["event"] as? String, 
           ["regionEnter", "beaconRanged", "beaconDetected", "offlineDetection"].contains(event) {

            let cleanData = data.compactMapValues { $0 }
            FlutterBackgroundExecutor.shared.execute(beaconData: cleanData)
        }
      }
    }
  }

  // Notification Tap Delegate
  public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
      let userInfo = response.notification.request.content.userInfo
      
      if let action = userInfo["action"] as? String, action == "beacon_detected" {
        send([
          "event": "notificationTapped",
          "data": userInfo
        ])
      }
      completionHandler()
    }
    
  public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.alert, .sound, .badge])
  }
}
