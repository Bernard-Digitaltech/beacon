import Foundation
import os

class Logger {
    
  private static let subsystem = Bundle.main.bundleIdentifier ?? "com.xenber.beaconsdk"

  @available(iOS 14.0, *)
  private static let osLog = os.Logger(subsystem: subsystem, category: "BeaconSDK")

  static func i(_ message: String) {
    print("[INFO] \(message)")
    
    if #available(iOS 14.0, *) {
      osLog.info("\(message, privacy: .public)")
    }
  }

  static func e(_ message: String, _ error: Error? = nil) {
    var logMessage = "[ERROR] \(message)"
    
    if let err = error {
      logMessage += " | Details: \(err.localizedDescription)"
    }
    
    print(logMessage)
    
    if #available(iOS 14.0, *) {
        osLog.error("\(logMessage, privacy: .public)")
    }
  }

  static func d(_ message: String) {
    #if DEBUG
    print("[DEBUG] \(message)")
    
    if #available(iOS 14.0, *) {
        osLog.debug("\(message, privacy: .public)")
    }
    #endif
  }
}