package com.xenber.beaconsdk.diagnostic

import com.xenber.beaconsdk.util.Logger

internal class SdkTracker {
  
  @Volatile var lastStep: String? = null
  @Volatile var lastErrorCode: Int? = null
  @Volatile var lastErrorMessage: String? = null

  fun step(step: String) {
    lastStep = step
    Logger.i(" [SDK][Diagnostic] Step: $step")
  }

  fun error(code: Int, message: String, t:Throwable? = null) {
    lastErrorCode = code
    lastErrorMessage = message
    Logger.e(" [SDK][Diagnostic] Error $code: $message", t)
  }

  fun snapshot(
    state: String,
    isInitialized: Boolean,
    isMonitoring: Boolean
  ): SdkDiagnostic {
    return SdkDiagnostic(
      state = state,
      isInitialized = isInitialized,
      isMonitoring = isMonitoring,
      lastStep = lastStep,
      lastErrorCode = lastErrorCode,
      lastErrorMessage = lastErrorMessage
    )
  }

  fun resetErrors() {
    lastErrorCode = null
    lastErrorMessage = null
  }
}