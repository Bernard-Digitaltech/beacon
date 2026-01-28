package com.xenber.frontend_v2

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle
import com.xenber.frontend_v2.BeaconBridgePlugin

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val NAVIGATION_CHANNEL = "com.xenber.frontend_v2/navigation"
    }
    
    private var navigationChannel: MethodChannel? = null
    private var pendingNavigationData: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        
        super.configureFlutterEngine(flutterEngine)
        // Register beacon bridge plugin
        try {
            flutterEngine.plugins.add(BeaconBridgePlugin())
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to register BeaconBridgePlugin: ${e.message}")
        }
        
        // Create navigation channel for handling notification taps
        navigationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)

        pendingNavigationData?.let { data ->
            navigationChannel?.invokeMethod("onNotificationTap", data)
            pendingNavigationData = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            handleIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        
        val action = intent.getStringExtra("action")
        
        if (action == "beacon_detected") {
            val macAddress = intent.getStringExtra("mac_address") ?: ""
            val locationName = intent.getStringExtra("location_name") ?: ""
            val rssi = intent.getIntExtra("rssi", 0)
            val timestamp = intent.getLongExtra("timestamp", 0)
            
            
            val navigationData = mapOf(
                "action" to "beacon_detected",
                "macAddress" to macAddress,
                "locationName" to locationName,
                "rssi" to rssi,
                "timestamp" to timestamp
            )
            
            // Send to Flutter
            if (navigationChannel != null) {
                navigationChannel?.invokeMethod("onNotificationTap", navigationData)
            } else {
                pendingNavigationData = navigationData
            }
        }
    }
}