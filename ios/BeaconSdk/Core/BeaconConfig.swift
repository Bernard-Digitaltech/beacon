import Foundation

struct BeaconConfig {
    var gatewayUrl: String
    var dataUrl: String
    var userId: String
    var rssiThreshold: Int
    var timeThreshold: Int 
    var scanPeriod: Int 
    var betweenScanPeriod: Int
    var notificationCooldown: Int 
}