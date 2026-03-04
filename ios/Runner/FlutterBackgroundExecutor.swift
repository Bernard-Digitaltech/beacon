import Foundation
import Flutter

class FlutterBackgroundExecutor {
    
    static let shared = FlutterBackgroundExecutor()
    
    private var backgroundEngine: FlutterEngine?
    private var backgroundChannel: FlutterMethodChannel?

    func execute(beaconData: [String: Any]) {
        let handle = UserDefaults.standard.object(forKey: "dispatcher_handle") as? Int64 ?? -1
        sendDebugNoti("2: Executor Start", "Handle ID: \(handle)")

        if handle == -1 {
            Logger.e("No background callback handle found!")
            return
        }

        if backgroundEngine == nil {
            guard let callbackInfo = FlutterCallbackCache.lookupCallbackInformation(handle) else {
                Logger.e("Fatal: Failed to find callback info.")
                return
            }

            sendDebugNoti("3: Booting Engine", "Starting headless Dart isolate.")


            backgroundEngine = FlutterEngine(name: "BeaconBackgroundEngine")

            // This allows background Dart code to use shared_preferences, network
            GeneratedPluginRegistrant.register(with: backgroundEngine!)

            backgroundEngine?.run(
                withEntrypoint: callbackInfo.callbackName, 
                libraryURI: callbackInfo.callbackLibraryPath
            )

            if let messenger = backgroundEngine?.binaryMessenger {
                backgroundChannel = FlutterMethodChannel(
                    name: "com.xenber.frontend_v2/beacon_background",
                    binaryMessenger: messenger
                )
            }
        }
        sendDebugNoti("4: Invoking Method", "Invoking background method.")
        backgroundChannel?.invokeMethod("onBackgroundBeaconDetected", arguments: beaconData)
    }
}