import Foundation

struct SdkDiagnostic {
  let state: String
  let isInitialized: Bool
  let isMonitoring: Bool
  let lastStep: String?
  let lastErrorCode: Int?
  let lastErrorMessage: String?
  let timestamp: Int64
  
  init(state: String, 
      isInitialized: Bool, 
      isMonitoring: Bool, 
      lastStep: String?, 
      lastErrorCode: Int?, 
      lastErrorMessage: String?) {
    
    self.state = state
    self.isInitialized = isInitialized
    self.isMonitoring = isMonitoring
    self.lastStep = lastStep
    self.lastErrorCode = lastErrorCode
    self.lastErrorMessage = lastErrorMessage
    self.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
  }
}