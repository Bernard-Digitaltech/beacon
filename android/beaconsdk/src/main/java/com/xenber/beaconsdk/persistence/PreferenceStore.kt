package com.xenber.beaconsdk.persistence

import android.content.Context
import android.content.SharedPreferences
import com.xenber.beaconsdk.BeaconConfig
import com.xenber.beaconsdk.network.GatewayClient
import org.json.JSONArray
import org.json.JSONObject

class PreferenceStore(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("beacon_sdk_prefs", Context.MODE_PRIVATE)
    
    fun setMonitoringEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_MONITORING_ENABLED, enabled).apply()
    }

    fun isMonitoringEnabled(): Boolean {
        return prefs.getBoolean(KEY_MONITORING_ENABLED, false)
    }
    
    private var gatwayClient: GatewayClient? = null

    companion object {
        private const val KEY_LAST_NOTIFY = "last_notify_"
        private const val KEY_NOTIFY_COUNT = "notify_count_"
        private const val KEY_LAST_STRONG = "last_strong_"
        private const val KEY_TARGET_BEACONS = "target_beacons"
        private const val KEY_CONFIG = "sdk_config"
        private const val KEY_MONITORING_ENABLED = "monitoring_enabled"
    }
    
    // --- Config Persistence ---
    fun saveConfig(config: BeaconConfig) {
        val json = JSONObject().apply {
            put("gatewayUrl", config.gatewayUrl)
            put("dataUrl", config.dataUrl)
            put("userId", config.userId)
            //put("authToken", config.authToken)
            put("rssiThreshold", config.rssiThreshold)
            put("timeThreshold", config.timeThreshold)
            put("scanPeriod", config.scanPeriod)
            put("betweenScanPeriod", config.betweenScanPeriod)
        }
        prefs.edit().putString(KEY_CONFIG, json.toString()).apply()
    }
    
    fun getConfig(): BeaconConfig? {
        val jsonString = prefs.getString(KEY_CONFIG, null) ?: return null
        return try {
            val json = JSONObject(jsonString)
            BeaconConfig(
                gatewayUrl = json.getString("gatewayUrl"),
                dataUrl = json.getString("dataUrl"),
                userId = json.getString("userId"),
                //authToken = json.getString("authToken"),
                rssiThreshold = json.optInt("rssiThreshold", -85),
                timeThreshold = json.optInt("timeThreshold", 2),
                scanPeriod = json.optLong("scanPeriod", 1100L),
                betweenScanPeriod = json.optLong("betweenScanPeriod", 5000L)
            )
        } catch (e: Exception) {
            null
        }
    }


    //--- Target Beacons ---
    fun putMap(key: String, map: Map<String, String>) {
        if (key == "targetBeacons") {
            val jsonArray = JSONArray()
            map.forEach { (mac, name) ->
                jsonArray.put(JSONObject().apply {
                    put("mac", mac)
                    put("name", name)
                })
            }
            prefs.edit().putString(KEY_TARGET_BEACONS, jsonArray.toString()).apply()
        }
    }

    
    fun remove(key: String) {
        if (key == "targetBeacons") {
            prefs.edit().remove(KEY_TARGET_BEACONS).apply()
        }
    }

    fun getTargetBeacons(): MutableMap<String, String> {
        val map = mutableMapOf<String, String>()
        val jsonString = prefs.getString(KEY_TARGET_BEACONS, null) ?: return map
        try {
            val jsonArray = JSONArray(jsonString)
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                map[obj.getString("mac")] = obj.getString("name")
            }
        } catch (e: Exception) {
            // Ignore error
        }
        return map
    }

    /* ---------- Notification Cooldown ---------- */

    fun getLastNotification(mac: String): Long =
        prefs.getLong(KEY_LAST_NOTIFY + mac, 0L)

    fun setLastNotification(mac: String, time: Long) {
        prefs.edit()
            .putLong(KEY_LAST_NOTIFY + mac, time)
            .apply()
    }

    /* ---------- Maintenance ---------- */

    fun clear(mac: String) {
        prefs.edit()
            .remove(KEY_LAST_NOTIFY + mac)
            .remove(KEY_NOTIFY_COUNT + mac)
            .remove(KEY_LAST_STRONG + mac)
            .apply()
    }

    fun clearAll() {
        prefs.edit().clear().apply()
    }
}