package com.xenber.beaconsdk.network

import android.content.ContentResolver
import android.provider.Settings
import com.xenber.beaconsdk.BeaconConfig
import com.xenber.beaconsdk.util.Logger
import com.xenber.beaconsdk.diagnostic.SdkTracker
import com.xenber.beaconsdk.diagnostic.SdkErrorCodes
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import kotlin.concurrent.thread

class GatewayClient(
    private val config: BeaconConfig,
    private val contentResolver: ContentResolver
) {

    private val sdkTracker = SdkTracker()

    interface GatewayCallback {
        fun onSuccess(response: JSONObject)
        fun onError(code: Int?, message: String)
    }

    fun fetchBeacons(callback: (Map<String, String>) -> Unit) {
        val dataUrl = config.dataUrl?.trim() ?: return

        if (!dataUrl.startsWith("http")) {
            Logger.e("Invalid data URL")
            return
        }

        thread {
            try {
                val conn = URL(dataUrl).openConnection() as HttpURLConnection
                conn.apply {
                    requestMethod = "GET"
                    setRequestProperty("Accept", "application/json")
                    // config.authToken?.takeIf { it.isNotBlank() }?.let {
                    //     setRequestProperty("Authorization", "Bearer $it")
                    // }
                    connectTimeout = 10_000
                    readTimeout = 10_000
                }

                val code = conn.responseCode
                if (code == 200) {
                    val responseText = conn.inputStream.bufferedReader().readText()
                    val json = JSONObject(responseText)
                    val dataArray = json.getJSONArray("data")

                    val beaconMap = mutableMapOf<String, String>()
                    for (i in 0 until dataArray.length()) {
                        val beacon = dataArray.getJSONObject(i)
                        val mac = beacon.getString("beacon_mac").uppercase()
                        val name = beacon.getString("location_name")
                        beaconMap[mac] = name
                    }
                    Logger.i("Fetched ${beaconMap.size} beacons from server")
                    callback(beaconMap)
                } else {
                    Logger.e("Failed to fetch beacons, code: $code")
                }
            } catch (e: Exception) {
                SdkTracker().error(
                    SdkErrorCodes.NETWORK_ERROR,
                    "Data fetch error: ${e.message}"
                )
                throw e
                Logger.e("Network error during beacon sync: ${e.message}")
            }
        }
    }


    fun sendDetection(
        mac: String,
        rssi: Int,
        battery: Int?,
        isInitial: Boolean = true,
        callback: GatewayCallback
    ) {
        val body = JSONObject().apply {
            put("type", "beacon_detection")
            put("user_id", config.userId)
            put("phone_id", getDeviceId())
            put("beacon_mac", mac)
            put("rssi", rssi)
            put("battery", battery ?: JSONObject.NULL)
            put("is_initial", isInitial)
            put("timestamp", getKLTimestamp())
        }

        executeRequest(body, callback)
    }

    fun sendEvent(
        eventType: String,
        details: JSONObject,
        callback: GatewayCallback? = null
    ) {
        val body = JSONObject().apply {
            put("type", "gateway_event")
            put("event_type", eventType)
            put("user_id", config.userId)
            put("phone_id", getDeviceId())
            put("details", details)
            put("timestamp", getKLTimestamp())
        }

        executeRequest(body, callback)
    }

    private fun executeRequest(
        body: JSONObject,
        callback: GatewayCallback?
    ) {
        val gatewayUrl = config.gatewayUrl.trim()
        if (!gatewayUrl.startsWith("http")) {
            callback?.onError(null, "Invalid gateway URL")
            return
        }

        thread {
            try {
                val conn = URL(gatewayUrl).openConnection() as HttpURLConnection
                val payload = body.toString().toByteArray(Charsets.UTF_8)

                Logger.i("📤 [Gateway] Sending ${body.optString("type")}: $body")

                conn.apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                    setRequestProperty("Accept", "application/json")
                    // config.authToken?.takeIf { it.isNotBlank() }?.let {
                    //     setRequestProperty("Authorization", "Bearer $it")
                    // }

                    setRequestProperty("Content-Length", payload.size.toString())
                    doOutput = true
                    doInput = true
                    useCaches = false
                    connectTimeout = 10_000
                    readTimeout = 10_000
                }

                conn.outputStream.use { it.write(payload) }

                val code = conn.responseCode
                val responseText = try {
                    if (code in 200..299)
                        conn.inputStream.bufferedReader().readText()
                    else
                        conn.errorStream?.bufferedReader()?.readText()
                } catch (e: Exception) {
                    null
                }

                if (code == 200 && responseText != null) {
                    callback?.onSuccess(JSONObject(responseText))
                } else {
                    callback?.onError(code, responseText ?: "Empty response")
                }

            } catch (e: Exception) {
                SdkTracker().error(
                    SdkErrorCodes.NETWORK_ERROR,
                    "Gateway transport error: ${e.message}"
                )
                throw e
                Logger.e("Gateway transport error: ${e.message}")
                callback?.onError(null, e.message ?: "Gateway error")
            }   
        }
    }

    private fun getDeviceId(): String {
        return Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown_device"
    }

    private fun getKLTimestamp(): String {
        return ZonedDateTime
            .now(ZoneId.of("Asia/Kuala_Lumpur"))
            .format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))
    }
}
