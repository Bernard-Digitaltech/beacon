//** Manages the scan lifecycle, detection logic, and reports to both Flutter and the Laravel Gateway.*/

package com.xenber.beaconsdk.monitoring

import android.content.Context
import com.xenber.beaconsdk.BeaconConfig
import com.xenber.beaconsdk.bridge.FlutterEventBridge
import com.xenber.beaconsdk.bridge.EventListener
import com.xenber.beaconsdk.core.BeaconLifecycle
import com.xenber.beaconsdk.core.BeaconWatchdog
import com.xenber.beaconsdk.core.BeaconInitializer
import com.xenber.beaconsdk.core.WakeLockController
import com.xenber.beaconsdk.detection.DetectionEngine
import com.xenber.beaconsdk.network.GatewayClient
import com.xenber.beaconsdk.notification.NotificationFactory
import com.xenber.beaconsdk.persistence.PreferenceStore
import com.xenber.beaconsdk.util.Logger
import com.xenber.beaconsdk.diagnostic.SdkTracker
import com.xenber.beaconsdk.diagnostic.SdkErrorCodes
import com.xenber.beaconsdk.core.RawBleScanner
import org.json.JSONObject

import java.util.concurrent.ConcurrentHashMap

class BeaconMonitor(
    private val context: Context,
    private val initializer: BeaconInitializer,
    private val lifecycle: BeaconLifecycle,
    private val wakeLock: WakeLockController,
    private val watchdog: BeaconWatchdog,
    private val flutterBridge: FlutterEventBridge,
    private val prefs: PreferenceStore,
) : DetectionEngine.DetectionListener {

    private var detectionEngine: DetectionEngine? = null
    private var gatewayClient: GatewayClient? = null
    private var regionController: BeaconRegionController? = null
    private var eventListener: EventListener? = null
    private val sdkTracker = SdkTracker()
    private val rawScanner = RawBleScanner(context) { mac: String, battery: Int ->
        onBatteryUpdated(mac, battery)
    }
    
    private val targetBeacons = mutableMapOf<String, String>()
    private var isMonitoring = false
    private var withinShift: Boolean = false
    private var config: BeaconConfig? = null

    private val batteryCache = ConcurrentHashMap<String, Int>()

    init {
        
        watchdog.setOnTimeoutListener {
            Logger.e("Watchdog triggered restart")
            if (isMonitoring) {
                stop()
                start()
            }
        }
    }

    fun applyConfig(cfg: BeaconConfig) {
        this.config = cfg
        this.detectionEngine = DetectionEngine(cfg, this)
        this.gatewayClient = GatewayClient(cfg, context.contentResolver)
        
        this.regionController = BeaconRegionController(initializer.beaconManager, this, context)
        regionController?.configureScanPeriods(cfg)
            ?: Logger.e("RegionController not initialized")
        
        Logger.i("BeaconMonitor: Config applied.")
        getTargetFromServer()
    }

    fun addTarget(mac: String, name: String) {
        val normalized = mac.uppercase()
        targetBeacons[normalized] = name
        prefs.putMap("targetBeacons", targetBeacons)
        Logger.i("Target added: $normalized ($name)")
    }

    fun clearTargets() {
        stop()
        targetBeacons.clear()
        prefs.remove("targetBeacons")
        Logger.i("All target beacons cleared")
    }

    fun start() {
        val currentConfig = config
        if (currentConfig == null) {
             Logger.e("Cannot start: Config not applied")
             return
        }

        if (isMonitoring) {
            Logger.i("Already monitoring")
            rawScanner.startScan()
            return
        }

        if (targetBeacons.isEmpty()) {
            Logger.i("No target beacons configured, fetching from server...")
            getTargetFromServer()
            return
            }   

        try {
            Logger.i("Starting monitoring engine...")
            regionController?.startMonitoring(targetBeacons.keys.toList())
            isMonitoring = true
            sendEvent("monitoringStarted", mapOf("targetCount" to targetBeacons.size))
            gatewayClient?.sendEvent("SCAN_STARTED", JSONObject().apply {
                put("device_model", android.os.Build.MODEL)
                put("os_version", android.os.Build.VERSION.RELEASE)
                }
            )
        } catch (e: Exception) {
            Logger.e("Fatal error starting monitor: ${e.message}")
            gatewayClient?.sendEvent("SCAN_ERROR", JSONObject().apply {
                put("error", (e.message ?: "Unknown"))
            })
        }

        rawScanner.startScan()
    }

    fun stop() {
        if (!isMonitoring) return
        Logger.i("Stopping monitoring...")
        watchdog.stop()
        regionController?.stopMonitoring()
        wakeLock.release()
        isMonitoring = false
        sendEvent("monitoringStopped")
        gatewayClient?.sendEvent("SCAN_STOPPED", JSONObject().apply {
            put("device_model", android.os.Build.MODEL)
            put("os_version", android.os.Build.VERSION.RELEASE)
        })
        
        rawScanner.stopScan()
        batteryCache.clear()
    }

    override fun onBeaconRanged(
        mac: String, 
        locationName: String, 
        rssi: Int, 
        avgRssi: Int, 
        timestamp: Long,
        isBackground: Boolean,
        battery: Int?
    ) {
        watchdog.notifyScan() 
        sendEvent("beaconRanged", mapOf(
            "macAddress" to mac,
            "locationName" to locationName,
            "rssi" to rssi,
            "avgRssi" to avgRssi,
            "timestamp" to timestamp,
            "isBackground" to isBackground,
            "battery" to battery
        ))
    }

    override fun onBeaconDetected(
        mac: String, 
        locationName: String, 
        avgRssi: Int, 
        timestamp: Long,
        battery: Int?
    ) {
        if (!withinShift) {
            Logger.i("Detection ignored: outside shift window")
            sendEvent("OutsideShiftDetection", mapOf(
                "macAddress" to mac,
                "locationName" to locationName,
                "avgRssi" to avgRssi,
                "timestamp" to timestamp,
                "battery" to battery
            ))
            return
        }
        val cfg = config ?: return
        val now = System.currentTimeMillis()
        val lastNotif = prefs.getLastNotification(mac)
        
        if (now - lastNotif < cfg.notificationCooldown) {
            Logger.i("Cooldown active for $locationName")
            return
        }
        
        // Call Gateway
        gatewayClient?.sendDetection(mac, avgRssi, battery, true, object: GatewayClient.GatewayCallback {
            override fun onSuccess(response: JSONObject) {
                 if (response.optBoolean("trigger_noti", false)) {
                     val params = response.optJSONObject("params") ?: JSONObject()
            
                     NotificationFactory.showInternalNotification(context, mac, params)
                     
                     prefs.setLastNotification(mac, now)
                     sendEvent("beaconDetected", mapOf(
                         "macAddress" to mac,
                         "locationName" to locationName,
                         "avgRssi" to avgRssi,
                         "timestamp" to timestamp,
                         "battery" to battery
                     ))
                 }
            }

            override fun onError(code: Int?, message: String) {
                Logger.e("Gateway error $code: $message")
            }
        })

        gatewayClient?.sendEvent("BEACON_DETECTED", JSONObject().apply {
                put("device_model", android.os.Build.MODEL)
                put("os_version", android.os.Build.VERSION.RELEASE)
                }
            )
    }

    override fun onBeaconLost(mac: String) {
        Logger.i("🏳️ Beacon Lost: $mac")
        sendEvent("beaconLost", mapOf("macAddress" to mac))
    }

    fun processRawRange(beacons: Collection<org.altbeacon.beacon.Beacon>) {
        if (!isMonitoring) return
        val engine = detectionEngine ?: return
        
        try {
            beacons.forEach { beacon ->
                val mac = beacon.bluetoothAddress.uppercase()
                val name = targetBeacons[mac] ?: "Unknown Device"

                // val battery = beacon.extraDataFields
                //     .firstOrNull()
                //     ?.toInt()

                val battery = batteryCache[mac]

                if (battery != null) {
                    Logger.i("🔋 Battery $battery% from $mac")
                }

                engine.processBeacon(
                    mac,
                    name,
                    beacon.rssi,
                    !lifecycle.isForeground(),
                    battery = battery
                )
            }
            
            engine.checkLostBeacons()
        } catch (e: Exception) {
            sdkTracker.error(
                SdkErrorCodes.DETECTION_ENGINE_ERROR,
                "Error processing ranged beacons."
            )
            throw e
        }
    }

    fun checkShift(shiftStartTime: Long,shiftEndTime: Long, timestamp: Long, bufferEarlyCheckIn: Long, bufferLateCheckIn: Long, bufferEarlyCheckOut: Long, bufferLateCheckOut: Long): Boolean {
        val engine = detectionEngine ?: return false

        val result = engine.isWithinShift(shiftStartTime, shiftEndTime, timestamp, bufferEarlyCheckIn, bufferLateCheckIn, bufferEarlyCheckOut, bufferLateCheckOut)
        withinShift = result
        Logger.i("Shift check result: $withinShift")
        return withinShift
    }
    

    fun getStatus(): Map<String, Any> {
        return mapOf(
            "isMonitoring" to isMonitoring,
            "targetCount" to targetBeacons.size,
            "isForeground" to lifecycle.isForeground(),
            "userId" to (config?.userId ?: "none")
        )
    }

    fun setEventListener(listener: EventListener?) {
        this.eventListener = listener
    }

    internal fun sendEvent(event: String, data: Map<String, Any?> = emptyMap()) {
        val payload = mapOf("event" to event) + data

        flutterBridge.send(payload)

        eventListener?.let { listener ->
            when (event) {
                "beaconRanged" -> listener.onBeaconRanged(payload)
                "beaconDetected" -> listener.onBeaconDetected(payload)
                "beaconLost" -> listener.onBeaconLost(payload) 
                "monitoringStarted" -> listener.onMonitoringStarted(payload)
                "monitoringStopped" -> listener.onMonitoringStopped(payload)
                "regionEnter" -> listener.onRegionEnter(payload)
                "regionExit" -> listener.onRegionExit(payload)
                "OutsideShiftDetection" -> listener.onOutsideShiftDetection(payload)
                else -> listener.onEvent(event, payload)
            }
        }
    }

    internal fun getTargetName(mac: String) = targetBeacons[mac.uppercase()]

    private fun getTargetFromServer() {
        gatewayClient?.fetchBeacons{ serverBeacons ->
            if (serverBeacons.isNotEmpty()) {
                synchronized(targetBeacons) {
                    targetBeacons.clear()
                    targetBeacons.putAll(serverBeacons)
                    prefs.putMap("targetBeacons", targetBeacons)
                    Logger.i("Fetched ${serverBeacons.size} target beacons from server")

                    if (!isMonitoring) {
                        Logger.i("Starting monitoring after beacon fetch")
                        start()
                    } 
                }
            } else {
                Logger.i("Server returned empty beacon list.")
            }
        }
    }

    private fun onBatteryUpdated(mac: String, battery: Int) {
        val normalized = mac.uppercase()

        if (!targetBeacons.containsKey(normalized)) return

        val old: Int? = batteryCache[normalized]
        if (old != battery) {
            Logger.i("🔋 Battery update $normalized: $battery%")
            batteryCache[normalized] = battery
        }
    }
}
