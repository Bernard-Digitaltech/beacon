import Foundation
import CoreLocation

public class BeaconSDK: NSObject {

  private enum State: Int, Comparable {
    case created = 0
    case initialized = 1
    case configured = 2
    case running = 3

    static func < (lhs: State, rhs: State) -> Bool {
      return lhs.rawValue < rhs.rawValue
    }
  }

  public static let shared = BeaconSDK()
  private var state: State = .created
  private var eventSink:(([String: Any?]) -> Void)?
  
  private let prefs = PreferenceStore()
  private let lifecycle = BeaconLifecycle()
  private let watchdog = BeaconWatchdog()
  private let initializer = BeaconInitializer()
  //private let flutterBridge = FlutterBridge.shared
  private let sdkTracker = SdkTracker()

  private var currentConfig: BeaconConfig?

  private lazy var monitor: BeaconRegionMonitor = {
    let m = BeaconRegionMonitor(
      prefs: prefs,
      lifecycle: lifecycle,
      watchdog: watchdog
    ) 
    m.onEvent = {[weak self] data in
        self?.eventSink?(data)
      }
    return m
  }()

  // private lazy var monitor: BeaconRegionMonitor = {
  //   return BeaconRegionMonitor(
  //     prefs: prefs,
  //     lifecycle: lifecycle,
  //     watchdog: watchdog,
  //     flutterBridge: FlutterBridge.shared
  //   )
  // }()

  private override init() {
    super.init()
    restoreIfNeeded()
    Logger.i("iOS BeaconSDK instance created")
  }

  public func initialize() {
    sdkTracker.step("SDK.initialize")
    guard state == .created else {return}

    Logger.i("[SDK] Initializing core components")
    do {
      watchdog.start()
      if let cfg = currentConfig {
          initializer.initialize(config: cfg, delegate: monitor)
       } else {
          Logger.i("Skipping Initializer config (waiting for configure call)")
       }
      state = .initialized
    } catch {
      sdkTracker.error(.initializationFailed, "Failed to initialize SDK.", error)
    }
  }

  public func configure(config: BeaconConfig) {
    sdkTracker.step("SDK.configure")
    Logger.i("SDK configuring")
    
    do {
      self.currentConfig = config
      prefs.saveConfig(config)
      prefs.setMonitoringEnabled(true)

      initializer.initialize(config: config, delegate: monitor)
      
      monitor.applyConfig(config)
      state = .configured
    } catch {
      sdkTracker.error(.configurationInvalid, "Failed to acquire configurations.")
    }
  }
  
  public func addTarget(uuid: String, major: Int?, minor: Int?, name: String) {
    sdkTracker.step("SDK.addTarget")
    do {
      monitor.addTarget(uuid: uuid, major: major, minor: minor, name: name)
    } catch {
      sdkTracker.error(.inputError, "Invalid target input.", error)
    }
  }

  public func clearTargets() {
    monitor.clearTargets()
  }
  
  public func start() {
    sdkTracker.step("SDK.startMonitoring")
    guard state == .configured else {
      Logger.e("SDK is not configured")
      return
    }

    Logger.i("[SDK] Start Monitoring")
    do {
      monitor.start()
      state = .running
    } catch {
      sdkTracker.error(.monitoringNotStarted, "Failed to start monitoring.")
    }
  }

  public func stop() {
    guard state == .running else { return }

    Logger.i("[SDK] Stop Monitoring")
    monitor.stop()
    prefs.setMonitoringEnabled(false)
    state = .configured
  }

  public func checkShift(shiftStartTime: Double, shiftEndTime: Double, timestamp: Double, bufferEarlyIn: Double, bufferLateIn: Double, bufferEarlyOut: Double, bufferLateOut: Double) -> Bool {
    sdkTracker.step("SDK.checkShift")
    return monitor.checkShift(
      shiftStartTime: shiftStartTime,
      shiftEndTime: shiftEndTime,
      timestamp: timestamp,
      bufferEarlyIn: bufferEarlyIn,
      bufferLateIn: bufferLateIn,
      bufferEarlyOut: bufferEarlyOut,
      bufferLateOut: bufferLateOut
    )
  }

  public func setEventCallback(_ callback: (([String: Any?]) -> Void)?) {
    self.eventSink = callback
  }

  public func getStatus() -> [String: Any] {
    return monitor.getStatus()
  }

  public func getDiagnostics() -> [String: Any?] {
    let snapshot = sdkTracker.snapshot(
      state: String(describing: state),
      isInitialized: state >= .initialized,
      isMonitoring: state == .running
    )

    return [
      "state": snapshot.state,
      "isInitialized": snapshot.isInitialized,
      "isMonitoring": snapshot.isMonitoring,
      "lastStep": snapshot.lastStep,
      "lastErrorCode": snapshot.lastErrorCode,
      "lastErrorMessage": snapshot.lastErrorMessage,
      "timestamp": snapshot.timestamp
    ]
  }

  private func restoreIfNeeded() {
    guard let savedConfig = prefs.getConfig() else { return }
    let wasMonitoring = prefs.isMonitoringEnabled()

    Logger.i("[SDK] Restoring saved configuration")
    monitor.applyConfig(savedConfig)
    initializer.initialize(config: savedConfig, delegate: monitor)
    
    monitor.applyConfig(savedConfig)
    state = .configured

    if wasMonitoring {
        Logger.i("[SDK] Restoring active monitoring state")
        monitor.start()
        state = .running
    }
  }
}
