package com.xenber.beaconsdk.diagnostic

data class SdkDiagnostic(
    val state: String,
    val isInitialized: Boolean,
    val isMonitoring: Boolean,
    val lastStep: String?,
    val lastErrorCode: Int?,
    val lastErrorMessage: String?,
    val timestamp: Long = System.currentTimeMillis()
)