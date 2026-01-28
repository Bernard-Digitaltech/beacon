/** Monitor scan and recover it when scan stops */

package com.xenber.beaconsdk.core

import android.os.Handler
import android.os.HandlerThread
import com.xenber.beaconsdk.util.Logger

class BeaconWatchdog(
    private val checkInterval: Long = 60_000L,
    private val timeout: Long = 2 * 60_000L
) {

    private var watchdogThread: HandlerThread? = null
    private var watchdogHandler: Handler? = null

    private var lastScanTimestamp: Long = 0L
    private var isRunning = false

    private var onTimeout: (() -> Unit)? = null

    private val watchdogTask = object : Runnable {
        override fun run() {
            if (!isRunning) return

            val now = System.currentTimeMillis()
            val elapsed = now - lastScanTimestamp

            if (lastScanTimestamp > 0 && elapsed > timeout) {
                Logger.e("⚠️ BeaconWatchdog: No scans detected for ${elapsed}ms. Triggering recovery.")
                onTimeout?.invoke()
                lastScanTimestamp = now 
            }

            watchdogHandler?.postDelayed(this, checkInterval)
        }
    }

    fun start() {
        if (isRunning) return

        try {
            Logger.i("Starting BeaconWatchdog...")
     
            val thread = HandlerThread("BeaconWatchdogThread")
            thread.start()
            
            val handler = Handler(thread.looper)
            
            this.watchdogThread = thread
            this.watchdogHandler = handler
            this.isRunning = true
            this.lastScanTimestamp = System.currentTimeMillis()

            handler.postDelayed(watchdogTask, checkInterval)
            Logger.i("BeaconWatchdog active")
        } catch (e: Exception) {
            Logger.e("Failed to start Watchdog: ${e.message}")
        }
    }

    fun stop() {
        isRunning = false
        watchdogHandler?.removeCallbacks(watchdogTask)
        watchdogThread?.quitSafely()

        watchdogHandler = null
        watchdogThread = null

        Logger.i("BeaconWatchdog stopped")
    }

    fun notifyScan() {
        lastScanTimestamp = System.currentTimeMillis()
    }

    fun setOnTimeoutListener(listener: () -> Unit) {
        onTimeout = listener
    }
}
