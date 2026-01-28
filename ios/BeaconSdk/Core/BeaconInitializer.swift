import Foundation
import CoreLocation
import UserNotifications
import UIKit

class BeaconInitializer: NSObject {

  let locationManager = CLLocationManager

  private sdkTracker = SdkTracker()
  private var isInitialized = false

  private let notificationCenter = UNUserNotificationCenter.current()

  override init(){
    super.init()
  }

  // Initializes CoreLocation and Background capabilities
  func initialize(config: BeaconConfig, delegate: CLLocationManagerDelegate) {
    Logger.i("Initializing CLLocationManager")

    do {
      locationManager.delegate = delegate
      setupBackgroundExecution()
      configureScanParameters(config)
      requestPermissions()
      setupNotificationPermissions()

      isInitialized = true
      Logger.i("CLLocationManager initialized successfully")
    } catch {
      sdkTracker.error(SdkErrorCodes.beaconManagerError, "BeaconManager failed to start.", error)
    }
  }

  private func configureScanParameters(_ config: BeaconConfig) {

    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.pausesLocationUpdatesAutomatically = false  //prevent OD from killing location updates
    Logger.i("Scan config → Accuracy: Best, AutoPause: Off")
  }

  private func setupBackgroundExecution() {

    // REQUIRES "Location updates" to be checked in "Signing & Capabilities" -> "Background Modes"
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.showsBackgroundLocationIndicator = true 
    
    Logger.i("Background Location Updates ENABLED")
  }

  private func requestPermissions() {

    let status = locationManager.authorizationStatus

    if status == .notDetermined {
      locationManager.requestAlwaysAuthorization()
    } else if status == .authorizedWhenInUse {
      locationManager.requestAlwaysAuthorization()
    }
  }

  private func setupNotificationPermissions() {
    notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if granted {
        Logger.i("Notification permission granted")
      } else {
        Logger.e("Notification permission denied: \(String(describing: error))")
      }
    }
  }
}