import Foundation

enum SdkErrorCodes: Int {
  case initializationFailed = 1001
  case configurationInvalid = 1002
  case inputError = 1003

  case monitoringNotStarted = 2001
  case detectionEngineError = 2002

  case beaconManagerError = 3001
  case networkError = 3002

  case unknown = 9999
}