/** Prevents CPU sleep during bg scan */

package com.xenber.beaconsdk.core

import android.content.Context
import android.os.PowerManager
import com.xenber.beaconsdk.util.Logger

class WakeLockController (
  context: Context
) {

  private val powerManager = 
    context.getSystemService(Context.POWER_SERVICE) as PowerManager

  private var wakeLock: PowerManager.WakeLock? = null

  fun acquire(tag: String = "BeaconSDK::WakeLock"){
    if (wakeLock?.isHeld == true) return

    wakeLock = powerManager.newWakeLock(
      PowerManager.PARTIAL_WAKE_LOCK,
      tag
    ).apply {
      acquire(24*60*60*100L)
    }

    Logger.i("WakeLock Acquired.")
  }

  fun release() {
    try {
      wakeLock?.let {
        if (it.isHeld) {
          it.release()
          Logger.i("WakeLock Released.")
        }
      }
    } catch (e: Exception) {

      Logger.e("WakeLock released failed: ${e.message}")
    } finally {

      wakeLock = null
    }
  }

  fun isHeld(): Boolean = wakeLock?.isHeld == true
}

