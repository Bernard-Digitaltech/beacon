import Flutter
import UIKit

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
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    GeneratedPluginRegistrant.register(with: self)
    
    if let beaconRegistrar = self.registrar(forPlugin: "com.xenber.frontend_v2/beacon_bridge") {
        FlutterBridge.register(with: beaconRegistrar)
    }
    
    let _ = BeaconSDK.shared 

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}