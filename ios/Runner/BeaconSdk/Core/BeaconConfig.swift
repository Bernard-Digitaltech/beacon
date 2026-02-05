import Foundation

public struct BeaconConfig {
    //public var gatewayUrl: String
    public var dataUrl: String
    public var userId: String
    public var rssiThreshold: Int
    public var timeThreshold: Int 
    public var scanPeriod: Int 
    public var betweenScanPeriod: Int
    public var notificationCooldown: Int 

    public init(
        dataUrl: String,
        userId: String,
        rssiThreshold: Int = -85,
        timeThreshold: Int = 2,
        scanPeriod: Int = 1100,
        betweenScanPeriod: Int = 5000,
        notificationCooldown: Int = 60000
    ) {
        self.dataUrl = dataUrl
        self.userId = userId
        self.rssiThreshold = rssiThreshold
        self.timeThreshold = timeThreshold
        self.scanPeriod = scanPeriod
        self.betweenScanPeriod = betweenScanPeriod
        self.notificationCooldown = notificationCooldown
    }
}