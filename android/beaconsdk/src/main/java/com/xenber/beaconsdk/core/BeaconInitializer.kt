/**  Initialize and configure AltBeacon for Foreground service **/

package com.xenber.beaconsdk.core

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.xenber.beaconsdk.BeaconConfig
import com.xenber.beaconsdk.util.Logger
import com.xenber.beaconsdk.diagnostic.SdkTracker
import com.xenber.beaconsdk.diagnostic.SdkErrorCodes
import org.altbeacon.beacon.BeaconManager
import org.altbeacon.beacon.BeaconParser
import org.altbeacon.beacon.RangeNotifier

class BeaconInitializer(
  private val context: Context
){

  val beaconManager: BeaconManager = 
    BeaconManager.getInstanceForApplication(context).apply {
      setEnableScheduledScanJobs(false)
      }

  private val sdkTracker = SdkTracker()
  private var rangeNotifierAdded = false
  private var foregroundServiceEnabled = false

  companion object {
    const val FOREGROUND_SERVICE_CHANNEL = "beacon_foreground_service"
    const val FOREGROUND_SERVICE_ID = 456
  }

  fun initialize(config: BeaconConfig, rangeNotifier: RangeNotifier) {
    Logger.i("Initializing BeaconManager")

    try{
      BeaconManager.setDebug(true)

      configureParsers()
      setupForegroundService()
      configureScanPeriods(config)

      if (!rangeNotifierAdded) {
          beaconManager.addRangeNotifier(rangeNotifier)
          rangeNotifierAdded = true
      }

      Logger.i("BeaconManager initialized successfully")
    } catch (e: Exception) {
      sdkTracker.error(
        SdkErrorCodes.BEACON_MANAGER_ERROR,
        "BeaconManager failed to start."
      )
      throw e
    }
  }

  private fun configureParsers() {
    beaconManager.beaconParsers.clear()

    beaconManager.beaconParsers.add(
      BeaconParser("AltBeacon")
        .setBeaconLayout(BeaconParser.ALTBEACON_LAYOUT)
    )

    beaconManager.beaconParsers.add(
      BeaconParser("iBeacon")
        .setBeaconLayout("m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24")
    )

    beaconManager.beaconParsers.add(
      BeaconParser("Eddystone-UID")
        .setBeaconLayout(BeaconParser.EDDYSTONE_UID_LAYOUT)
    )

     Logger.i("Beacon parsers configured (${beaconManager.beaconParsers.size})")
  }


  private fun configureScanPeriods(config: BeaconConfig) {
    beaconManager.foregroundScanPeriod = config.scanPeriod
    beaconManager.foregroundBetweenScanPeriod = config.betweenScanPeriod

    beaconManager.backgroundScanPeriod = config.scanPeriod
    beaconManager.backgroundBetweenScanPeriod = config.betweenScanPeriod

    Logger.i(
      "Scan config → scan=${config.scanPeriod}ms, " +
      "between=${config.betweenScanPeriod}ms"
      )
  }

  private fun setupForegroundService() {
    createForegroundChannel()

    val notification = createForegroundNotification()

    if (!foregroundServiceEnabled) {
        beaconManager.enableForegroundServiceScanning(notification, FOREGROUND_SERVICE_ID)
        Logger.i("Foreground Service scanning ENABLED")
        foregroundServiceEnabled = true
    } else {
        Logger.i("Foreground Service scanning already enabled")
    }
  }

  private fun createForegroundChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

      val manager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

      val channel = NotificationChannel(
        FOREGROUND_SERVICE_CHANNEL,
        "Beacon Monitoring Service",
        NotificationManager.IMPORTANCE_LOW
      ).apply {
        description = "Active service for beacon scanning"
        setShowBadge(false)
      }

      manager.createNotificationChannel(channel)
  }

  private fun createForegroundNotification(): Notification {
    val launchIntent = context.packageManager
      .getLaunchIntentForPackage(context.packageName)

    val pendingIntent = PendingIntent.getActivity(
      context,
      0,
      launchIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    return NotificationCompat.Builder(context, FOREGROUND_SERVICE_CHANNEL)
      .setSmallIcon(android.R.drawable.ic_dialog_info)
      .setContentTitle("Beacon Monitoring Active")
      .setContentText("Scanning for nearby beacons")
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .setOngoing(true)
      .setContentIntent(pendingIntent)
      .build()
  }
}