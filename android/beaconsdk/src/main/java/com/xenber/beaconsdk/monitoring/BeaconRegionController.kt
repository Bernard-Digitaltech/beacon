//** BLE scanner adapter and report raw events */

package com.xenber.beaconsdk.monitoring

import android.content.Context
import org.altbeacon.beacon.*
import org.altbeacon.beacon.startup.RegionBootstrap
import org.altbeacon.beacon.startup.BootstrapNotifier
import com.xenber.beaconsdk.BeaconConfig
import com.xenber.beaconsdk.util.Logger

class BeaconRegionController(
    private val beaconManager: BeaconManager,
    private val monitor: BeaconMonitor,
    private val context: Context
) : RangeNotifier, MonitorNotifier, BootstrapNotifier  {

    private var regionBootstrap: RegionBootstrap? = null
    private var monitoringRegion: Region? = null

    override fun getApplicationContext(): Context {
        return context.applicationContext
    }

    fun configureScanPeriods(config: com.xenber.beaconsdk.BeaconConfig) {
        beaconManager.foregroundScanPeriod = config.scanPeriod
        beaconManager.foregroundBetweenScanPeriod = config.betweenScanPeriod
        beaconManager.backgroundScanPeriod = config.scanPeriod
        beaconManager.backgroundBetweenScanPeriod = config.betweenScanPeriod
        Logger.i("RegionController: Scan periods set")
    }

    fun startMonitoring(targetMacs: List<String>) {
        monitoringRegion = Region("all-beacons-region", null, null, null)

        regionBootstrap?.disable()
        regionBootstrap = RegionBootstrap(this, monitoringRegion!!)
        beaconManager.addRangeNotifier(this)

        Logger.i("RegionController: Monitoring started for ${targetMacs.size} targets")
    }

    fun stopMonitoring() {
        regionBootstrap?.disable()
        regionBootstrap = null
        beaconManager.removeRangeNotifier(this)
        if (monitoringRegion != null) {
            try { beaconManager.stopRangingBeacons(monitoringRegion!!) } catch (_: Exception) {}
        }
        monitoringRegion = null
        Logger.i("RegionController: Monitoring stopped")
    }

    override fun didEnterRegion(region: Region?) {
        Logger.i("Entered region: ${region?.uniqueId}")
        try { beaconManager.startRangingBeacons(region!!) } catch (_: Exception) {}
        monitor.sendEvent("regionEnter", mapOf("regionId" to (region?.uniqueId ?: "unknown")))
    }

    override fun didExitRegion(region: Region?) {
        Logger.i("Exited region: ${region?.uniqueId}")
        try { beaconManager.stopRangingBeacons(region!!) } catch (_: Exception) {}
        monitor.sendEvent("regionExit", mapOf("regionId" to (region?.uniqueId ?: "unknown")))
    }

    override fun didDetermineStateForRegion(state: Int, region: Region?) {
        val stateStr = if (state == MonitorNotifier.INSIDE) "INSIDE" else "OUTSIDE"
        Logger.i("Region ${region?.uniqueId} state: $stateStr")
        if (state == MonitorNotifier.INSIDE) {
            try { beaconManager.startRangingBeacons(region!!) } catch (_: Exception) {}
        }
    }

    override fun didRangeBeaconsInRegion(
        beacons: MutableCollection<Beacon>?,
        region: Region?
    ) {
        if (beacons.isNullOrEmpty()) {
            monitor.processRawRange(emptyList())
            return
        }

        monitor.processRawRange(beacons)
    }
}
