import Foundation

protocol DetectionEngineDelegate: AnyObject {
  func onBeaconRanged(mac: String, locationName: String, rssi: Int, avgRssi: Int, timestamp: Int64, isBackground: Bool, battery: Int?)
  func onBeaconDetected(mac: String, locationName: String, avgRssi: Int, timestamp: Int64, battery: Int?)
  func onBeaconLost(mac: String)
}

class DetectionEngine {
  private let RSSI_BUFFER_SIZE = 5

  private var config: BeaconConfig?
  private weak var delegate: DetectionEngineDelegate?

  private var rssiBuffers: [String: [Int]] = [:]
  private var detectionStartTimes: [String: Int64] = [:]
  private var lastSeenTimes: [String: Int64] = [:]
  private var lastKnownBattery: [String: Int] = [:]

  init(config: BeaconConfig? = nil, delegate: DetectionEngineDelegate? = nil) {
    self.config = config
    self.delegate = delegate
  }
    
  func configure(_ config: BeaconConfig) {
    self.config = config
  }

  func processBeacon(mac: String, locationName: String, rssi: Int, isBackground: Bool, battery: Int?) {
    guard let config = config else {return}

    let now = Int64(Date().timeIntervalSince1970 * 1000)
    lastSeenTimes[mac] = now

    // Not getting battery reading yet
    if let bat = battery {
      lastKnownBattery[mac] = bat
    }
    let currentBattery = lastKnownBattery[mac]

    if rssiBuffers[mac] == nil {rssiBuffers[mac] = [] }
    rssiBuffers[mac]?.append(rssi)

    if let count = rssiBuffers[mac]?.count, count > RSSI_BUFFER_SIZE {
      rssiBuffers[mac]?.removeFirst()
    }

    let buffer = rssiBuffers[mac] ?? []
    let sum = buffer.reduce(0, +)
    let avgRssi = buffer.isEmpty ? rssi:(sum/buffer.count)

    Logger.d("[\(mac)] \(locationName) | RSII: \(rssi)")

    delegate?.onBeaconRanged(
      mac: mac,
      locationName: locationName,
      rssi: rssi,
      avgRssi: avgRssi, 
      timestamp: now,
      isBackground: isBackground,
      battery: currentBattery
    )

    if avgRssi >= config.rssiThreshold {
      handleStrongSignal(mac: mac, locationName: locationName, avgRssi: avgRssi, battery: currentBattery, now: now)
    } else {
      reset(mac: mac)
    }
  }
  

  private func handleStrongSignal(mac: String, locationName: String, avgRssi: Int, battery: Int?, now: Int64) {
    guard let config = config else {return}

    if detectionStartTimes[mac] == nil {
      detectionStartTimes[mac] = now
      Logger.i(" Timer STARTED for \(locationName)")
    }
        
    let startTime = detectionStartTimes[mac]!
    let durationSeconds = (now - startTime) / 1000
    
    if durationSeconds >= Int64(config.timeThreshold) {
      Logger.i(" VALID DETECTION: \(locationName)")
      
      delegate?.onBeaconDetected(
        mac: mac,
        locationName: locationName,
        avgRssi: avgRssi,
        timestamp: now,
        battery: battery
      )

      reset(mac: mac)
    }
  }

  func isWithinShift(start: Double, end: Double, now: Double, earlyIn: Double, lateIn: Double, earlyOut: Double, lateOut: Double) -> Bool {
        
    let earliestCheckIn = start - earlyIn
    let latestCheckIn = start + lateIn
    
    let earliestCheckOut = end - earlyOut
    let latestCheckOut = end + lateOut
    
    let resultIn = (earliestCheckIn...latestCheckIn).contains(now)
    let resultOut = (earliestCheckOut...latestCheckOut).contains(now)
    
    let result = resultIn || resultOut
    
    Logger.i(result ? "Within shift window" : "Outside shift window")
    
    return result
  }

  func checkLostBeacons(timeoutMillis: Int64 = 5000) {
      let now = Int64(Date().timeIntervalSince1970 * 1000)
      
      let lostMacs = lastSeenTimes.filter { (key, lastSeen) in
        return (now - lastSeen) > timeoutMillis
      }
      
      for (mac, _) in lostMacs {
        Logger.i(" Beacon Lost: \(mac) (timed out)")
        reset(mac: mac)
        delegate?.onBeaconLost(mac: mac)
      }
    }
    
  private func reset(mac: String) {
    detectionStartTimes.removeValue(forKey: mac)
    rssiBuffers.removeValue(forKey: mac)
    lastSeenTimes.removeValue(forKey: mac)
  }
}