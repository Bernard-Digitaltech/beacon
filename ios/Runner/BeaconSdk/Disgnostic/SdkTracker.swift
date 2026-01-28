import Foundation

class SdkTracker {
    
  private let lock = NSLock()
  
  private var lastStep: String?
  private var lastErrorCode: Int?
  private var lastErrorMessage: String?
  
  func step(_ step: String) {
    lock.lock()
    defer { lock.unlock() }
    
    self.lastStep = step
    Logger.i("[SDK][Diagnostic] Step: \(step)")
  }
    
  func error(_ code: SdkErrorCodes, _ message: String, _ error: Error? = nil) {
    self.error(code.rawValue, message, error)
  }
  
  func error(_ code: Int, _ message: String, _ error: Error? = nil) {
    lock.lock()
    defer { lock.unlock() }
    
    self.lastErrorCode = code
    self.lastErrorMessage = message
    
    Logger.e("[SDK][Diagnostic] Error \(code): \(message)", error)
  }
    
  func snapshot(state: String, isInitialized: Bool, isMonitoring: Bool) -> SdkDiagnostic {
    lock.lock()
    defer { lock.unlock() }
    
    return SdkDiagnostic(
      state: state,
      isInitialized: isInitialized,
      isMonitoring: isMonitoring,
      lastStep: lastStep,
      lastErrorCode: lastErrorCode,
      lastErrorMessage: lastErrorMessage
    )
  }
  
  func resetErrors() {
    lock.lock()
    defer { lock.unlock() }
    
    lastErrorCode = nil
    lastErrorMessage = nil
  }
}