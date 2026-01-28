package com.xenber.frontend_v2

import androidx.annotation.NonNull
import com.xenber.beaconsdk.BeaconSDK
import com.xenber.beaconsdk.BeaconConfig
import com.xenber.beaconsdk.bridge.EventListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * This is the bridge that your existing Flutter app uses to talk to the new SDK.
 */
class BeaconBridgePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler{

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        android.util.Log.e("BEACON_PLUGIN", "🔥 BeaconBridgePlugin ATTACHED")
        
        val context = binding.applicationContext
        BeaconSDK.init(context)

        methodChannel = MethodChannel(binding.binaryMessenger, "com.xenber.frontend_v2/beacon_bridge")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "com.xenber.frontend_v2/beacon_events")
        eventChannel.setStreamHandler(this)
    }

    // Flutter → SDK
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val sdk = try {
            BeaconSDK.getInstanceOrThrow()
        } catch (e: Exception) {
            result.error("SDK_NOT_INIT", e.message, null)
            return
        }

        when (call.method) {

          "initialize" -> {
            try {
                sdk.initialize()   
                result.success(
                    mapOf(
                        "status" to "success",
                        "message" to "SDK core initialized"
                    )
                )
            } catch (e: Exception) {
                result.error("INIT_FAILED", e.message, null)
            }
        }

            "startMonitoring" -> {
                try {
                    val args = call.arguments as Map<*, *>
                    val config = BeaconConfig(
                        userId = args["userId"] as? String ?: "unknown",
                        //authToken = args["authToken"] as? String ?: "",
                        gatewayUrl = args["gatewayUrl"] as? String ?: "",
                        dataUrl = args["dataUrl"] as? String ?: "",
                        rssiThreshold = args["rssiThreshold"] as? Int ?: -85,
                        timeThreshold = args["timeThreshold"] as? Int ?: 2
                    )

                    sdk.configure(config)
                    sdk.start()
                    result.success(true)
                } catch (e: Exception) {
                    result.error("START_MONITORING_FAILED", e.message, null)
                }
            }

            "stopMonitoring" -> {
                sdk.stop()
                result.success(true)
            }

            "addTargetBeacon" -> {
                val mac = call.argument<String>("macAddress") ?: ""
                val name = call.argument<String>("locationName") ?: ""
                sdk.addTarget(mac, name)
                result.success(true)
            }

            "isMonitoring" -> {
                val status = sdk.getStatus()
                result.success(status["isMonitoring"] == true)
            }

            "validateShift" -> {
                val shiftStartTime = (call.argument<Number>("shiftStartTime") ?: 0).toLong()
                val shiftEndTime = (call.argument<Number>("shiftEndTime") ?: 0).toLong()
                val bufferEarlyCheckIn = (call.argument<Number>("bufferEarlyCheckIn") ?: 0).toLong()
                val bufferLateCheckIn = (call.argument<Number>("bufferLateCheckIn") ?: 0).toLong()
                  val bufferEarlyCheckOut = (call.argument<Number>("bufferEarlyCheckOut") ?: 0).toLong()
                val bufferLateCheckOut = (call.argument<Number>("bufferLateCheckOut") ?: 0).toLong()
                val timestamp   = (call.argument<Number>("timestamp") ?: 0).toLong()
                val withinShift = sdk.checkShift(shiftStartTime, shiftEndTime, timestamp, bufferEarlyCheckIn, bufferLateCheckIn, bufferEarlyCheckOut, bufferLateCheckOut)
                result.success(withinShift)
            }

            "getDiagnostic" -> {
                try {
                    result.success(BeaconSDK.getInstanceOrThrow().getDiagnostics())
                } catch (e: Exception) {
                    result.error("DIAGNOSTIC_FAILED", e.message, null)
                }
            }

            else -> result.notImplemented()
        }
    }

    // Flutter event channel lifecycle
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events

        // Pass a Kotlin lambda into SDK
        BeaconSDK.getInstanceOrThrow().setAndroidListener { event ->
            eventSink?.success(event)
        }
    }

    override fun onCancel(arguments: Any?) {
        BeaconSDK.getInstanceOrThrow().setAndroidListener(null)
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        BeaconSDK.getInstanceOrThrow().setAndroidListener(null)
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}