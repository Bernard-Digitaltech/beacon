//** Handles RSSI + Time Detection Logic for Target Beacons **/

package com.xenber.beaconsdk.detection

import com.xenber.beaconsdk.BeaconConfig
import com.xenber.beaconsdk.util.Logger
import kotlin.math.abs

class DetectionEngine(
    private val config: BeaconConfig,
    private val listener: DetectionListener
) {

    companion object {
        private const val RSSI_BUFFER_SIZE = 5
        //private const val CHECK_IN_BUFFER = 3600000L 
    }

    private val rssiBuffers = mutableMapOf<String, MutableList<Int>>()      
    private val detectionStartTimes = mutableMapOf<String, Long>()         
    private val lastSeenTimes = mutableMapOf<String, Long>()   
    private var withinShift: Boolean = false
    private val lastKnownBattery = mutableMapOf<String, Int>()         

    fun processBeacon(mac: String, locationName: String, rssi: Int, isBackground: Boolean, battery: Int?) {
        val now = System.currentTimeMillis()
        lastSeenTimes[mac] = now

        val buffer = rssiBuffers.getOrPut(mac) { mutableListOf() }
        buffer.add(rssi)
        if (buffer.size > RSSI_BUFFER_SIZE) buffer.removeAt(0)
        val avgRssi = buffer.average()

        if (battery != null) {
            lastKnownBattery[mac] = battery
        }
        val battery = lastKnownBattery[mac]

        Logger.i("[$mac] $locationName | RSSI: $rssi (avg: ${avgRssi.toInt()})") // | Bat: ${battery ?: "unknown"}%")

        listener.onBeaconRanged(
            mac, locationName, rssi, avgRssi.toInt(), timestamp = now, isBackground, battery
        )

        if (avgRssi >= config.rssiThreshold) {
            handleStrongSignal(mac, locationName, avgRssi, battery)
        } else {
            reset(mac)
        }
    }

    fun isWithinShift(shiftStartTime: Long,shiftEndTime: Long, timestamp: Long, bufferEarlyCheckIn: Long, bufferLateCheckIn: Long, bufferEarlyCheckOut: Long, bufferLateCheckOut: Long): Boolean {

        val earliestCheckInAllowed = shiftStartTime - bufferEarlyCheckIn
        val latestCheckInAllowed = shiftStartTime + bufferLateCheckIn

        val earliestCheckOutAllowed = shiftEndTime - bufferEarlyCheckOut
        val latestCheckOutAllowed = shiftEndTime + bufferLateCheckOut

        val resultIn = timestamp in earliestCheckInAllowed..latestCheckInAllowed
        val resultOut = timestamp in earliestCheckOutAllowed..latestCheckOutAllowed

        val result = resultIn || resultOut

        Logger.i(
            if (result)
                "Within shift window"
            else
                "Outside shift window"
        )

        return result
    }

    private fun handleStrongSignal(mac: String, locationName: String, avgRssi: Double, battery: Int?) {
        val now = System.currentTimeMillis()

        if (!detectionStartTimes.containsKey(mac)) {
            detectionStartTimes[mac] = now
            Logger.i("⏱️ Timer STARTED for $locationName")
        }

        val startTime = detectionStartTimes[mac]!!
        val durationSeconds = (now - startTime) / 1000

        if (durationSeconds >= config.timeThreshold) {
            Logger.i(" VALID DETECTION: $locationName")

            listener.onBeaconDetected(
                mac = mac,
                locationName = locationName,
                avgRssi = avgRssi.toInt(),
                timestamp = now,
                battery = battery
            )

            reset(mac)
        }
    }

    fun checkLostBeacons(timeoutMillis: Long = 5000) {
        val now = System.currentTimeMillis()
        val lostMacs = lastSeenTimes.filter { now - it.value > timeoutMillis }.keys

        lostMacs.forEach { mac ->
            Logger.i("🔌 Beacon Lost: $mac (timed out after ${timeoutMillis}ms)")
            reset(mac)
            listener.onBeaconLost(mac)
        }
    }

    private fun reset(mac: String) {
        detectionStartTimes.remove(mac)
        rssiBuffers.remove(mac)
        lastSeenTimes.remove(mac)
    }

    interface DetectionListener {
        fun onBeaconRanged(
            mac: String,
            locationName: String,
            rssi: Int,
            avgRssi: Int,
            timestamp: Long,
            isBackground: Boolean,
            battery: Int?
        )

        fun onBeaconDetected(
            mac: String,
            locationName: String,
            avgRssi: Int,
            timestamp: Long,
            battery: Int?
        )

        fun onBeaconLost(mac: String)
    }
}