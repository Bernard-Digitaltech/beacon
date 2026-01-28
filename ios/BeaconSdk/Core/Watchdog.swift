import Foundation

class BeaconWatchdog {
  
  private let checkInterval: TimeInterval
  private let timeout: TimeInterval

  private var timer: Timer?
  private var lastScanTimestamp: TimeInterval = 0
  private var isRunning = false

  var onTimeout: (() -> Void)?
    
  init(checkIntervalMs: Int = 60_000, timeoutMs: Int = 120_000) {
    self.checkInterval = TimeInterval(checkIntervalMs) / 1000.0 
    self.timeout = TimeInterval(timeoutMs) / 1000.0
  }

  func start() {
    if isRunning { return }
        
    Logger.i("Starting BeaconWatchdog...")
    isRunning = true
    lastScanTimestamp = Date().timeIntervalSince1970

    DispatchQueue.main.async {
      self.timer = Timer.scheduledTimer(
        timeInterval: self.checkInterval,
        target: self,
        selector: #selector(self.checkHealth),
        userInfo: nil,
        repeats: true
      )
    }
    Logger.i("BeaconWatchdog active")
  }

  func stop() {
    isRunning = false
    timer?.invalidate()
    timer = nil
    Logger.i("BeaconWatchdog stopped")
  }
    
  func notifyScan() {
    lastScanTimestamp = Date().timeIntervalSince1970
  }

  @objc private func checkHealth() {
    if !isRunning { return }
    
    let now = Date().timeIntervalSince1970
    let elapsed = now - lastScanTimestamp
    
    if lastScanTimestamp > 0 && elapsed > timeout {
      Logger.e(" BeaconWatchdog: No scans for \(Int(elapsed))s. Triggering recovery.")
      onTimeout?()
      lastScanTimestamp = now
    }
  }
}