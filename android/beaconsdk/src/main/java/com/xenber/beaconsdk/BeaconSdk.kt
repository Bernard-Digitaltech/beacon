package com.xenber.beaconsdk

import android.content.Context
import com.xenber.beaconsdk.bridge.FlutterEventBridge
import com.xenber.beaconsdk.core.BeaconInitializer
import com.xenber.beaconsdk.core.BeaconLifecycle
import com.xenber.beaconsdk.core.BeaconWatchdog
import com.xenber.beaconsdk.core.WakeLockController
import com.xenber.beaconsdk.monitoring.BeaconMonitor
import com.xenber.beaconsdk.persistence.PreferenceStore
import com.xenber.beaconsdk.util.Logger
import com.xenber.beaconsdk.diagnostic.SdkTracker
import com.xenber.beaconsdk.diagnostic.SdkErrorCodes
import org.altbeacon.beacon.Beacon
import org.altbeacon.beacon.RangeNotifier
import org.altbeacon.beacon.Region

import java.util.concurrent.ConcurrentHashMap

class BeaconSDK private constructor(context: Context) : RangeNotifier {

  private val appContext = context.applicationContext
  private val prefs = PreferenceStore(appContext)
  private val initializer = BeaconInitializer(appContext)
  private val lifecycle = BeaconLifecycle(appContext)
  private val wakeLock = WakeLockController(appContext)
  private val watchdog = BeaconWatchdog()
  private val flutterBridge = FlutterEventBridge()
  private val sdkTracker = SdkTracker()

  private val monitor = BeaconMonitor(
    appContext,
    initializer,
    lifecycle,
    wakeLock,
    watchdog,
    flutterBridge,
    prefs
  )

  private enum class State {
    CREATED,
    INITIALIZED,
    CONFIGURED,
    RUNNING
  }


  companion object {
    @Volatile 
    private var instance: BeaconSDK? = null
    private var state = State.CREATED

    fun init(context: Context): BeaconSDK {
      Logger.i("🔵 [SDK] Static init() called by ${context.javaClass.simpleName}")
      return instance ?: synchronized(this) {
        instance ?: BeaconSDK(context).also { sdk ->
          instance = sdk
          sdk.restoreIfNeeded()
          Logger.i("✅ BeaconSDK instance created")
        }
      }
    }

    fun getInstanceOrThrow(): BeaconSDK {
      return instance ?: throw IllegalStateException("BeaconSdk not initialized. Call init() first.")
      }
    }

  fun initialize() {
    sdkTracker.step("SDK.initialize")

    if (state != State.CREATED) return
    Logger.i("[SDK] Initializing core components")

    try {
      wakeLock.acquire()
      watchdog.start()
      state = State.INITIALIZED
    } catch (e: Exception) {
      sdkTracker.error(
        SdkErrorCodes.INITIALIZATION_FAILED,
        "Failed to initialize SDK.",
        e
      )
      throw e
    }

  }



  fun configure(config: BeaconConfig){
    sdkTracker.step("SDK.configure")
    Logger.i("SDK configuring")

    try {
      prefs.saveConfig(config)
      prefs.setMonitoringEnabled(true)
      initializer.initialize(config, this)
      monitor.applyConfig(config)
      state = State.CONFIGURED
    } catch (e: Exception) {
      sdkTracker.error(
        SdkErrorCodes.CONFIGURATION_INVALID,
        "Failed to acquire configurations."
      )
      throw e
    }

  }

  fun addTarget(mac: String, name:String){
    sdkTracker.step("SDK.addTarget")
    try{
      monitor.addTarget(mac, name)
      } catch (e: Exception) {
      sdkTracker.error(
        SdkErrorCodes.INPUT_ERROR,
        "Invalid target input.",
        e
      )
    }
  }

  fun clearTargets() {
    monitor.clearTargets()
  }

  fun start() {
    sdkTracker.step("SDK.startMonitoring")
    if (state != State.CONFIGURED) {
      throw IllegalStateException("SDK not configured")
    }
    Logger.i(" [SDK] Start monitoring")
    try {
      monitor.start()
      state = State.RUNNING
    } catch (e: Exception) {
      sdkTracker.error(
        SdkErrorCodes.MONITORING_NOT_STARTED,
        "Failed to start monitoring."
      )
      throw e
    }
  }

  fun stop() {
    if (state != State.RUNNING) return

    Logger.i("⏹ [SDK] Stop monitoring")
    monitor.stop()
    prefs.setMonitoringEnabled(false)
    state = State.CONFIGURED
  }

  fun checkShift(shiftStartTime: Long,shiftEndTime: Long, timestamp: Long, bufferEarlyCheckIn: Long, bufferLateCheckIn: Long, bufferEarlyCheckOut: Long, bufferLateCheckOut: Long): Boolean {
    sdkTracker.step("SDK.checkShift")

    return try{
      monitor.checkShift(shiftStartTime, shiftEndTime, timestamp, bufferEarlyCheckIn, bufferLateCheckIn, bufferEarlyCheckOut, bufferLateCheckOut)
      true
    } catch (e: Exception) {
      sdkTracker.error(
        SdkErrorCodes.INPUT_ERROR,
        "Invalid input for shift check."
      )
      throw e
      false
    }
  }

  fun setFlutterSink(sink: (Map<String, Any?>) -> Unit) {
    flutterBridge.setAndroidListener(sink)
  }

  fun setAndroidListener(listener: ((Map<String, Any?>) -> Unit)?) {
    flutterBridge.setAndroidListener(listener)
  }

  fun getStatus(): Map<String, Any> = monitor.getStatus()

  override fun didRangeBeaconsInRegion(beacons: MutableCollection<Beacon>?, region: Region?) {
    beacons?.let { monitor.processRawRange(it) }
  }

  private fun restoreIfNeeded() {
    val savedConfig = prefs.getConfig()
    val wasMonitoring = prefs.isMonitoringEnabled()

   if (savedConfig != null) {
    Logger.i("[SDK] Restoring saved configuration")
    initializer.initialize(savedConfig, this)
    monitor.applyConfig(savedConfig)
    state = State.CONFIGURED

    if (wasMonitoring) {
      Logger.i("[SDK] Restoring active monitoring state")
      monitor.start()
      state = State.RUNNING
      }
    }
  }

  fun getDiagnostics(): Map<String, Any?> {
    val snapshot = sdkTracker.snapshot(
      state = state.name,
      isInitialized = state >= State.INITIALIZED,
      isMonitoring = state == State.RUNNING
    )

    return mapOf(
      "state" to snapshot.state,
      "isInitialized" to snapshot.isInitialized,
      "isMonitoring" to snapshot.isMonitoring,
      "lastStep" to snapshot.lastStep,
      "lastErrorCode" to snapshot.lastErrorCode,
      "lastErrorMessage" to snapshot.lastErrorMessage,
      "timestamp" to snapshot.timestamp
    )
  }
}