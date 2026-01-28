/** Check App Lifecycle For Beacon Scanning (FG/BG) **/

package com.xenber.beaconsdk.core

import android.app.Application
import android.content.Context
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.xenber.beaconsdk.util.Logger

class BeaconLifecycle (
  context: Context
) {

  private var isForeground: Boolean = true
  private var listener: LifecycleListener? = null
  
  init {
    android.os.Handler(android.os.Looper.getMainLooper()).post {
      ProcessLifecycleOwner
        .get()
        .lifecycle
        .addObserver(object: LifecycleEventObserver {

          override fun onStateChanged(
            source: LifecycleOwner,
            event: Lifecycle.Event
          ) {
            when (event) {
              Lifecycle.Event.ON_START -> {
                isForeground = true
                Logger.i("App moved to FOREGROUND")
                listener?.onForeground()
              }
              Lifecycle.Event.ON_STOP -> {
                isForeground = false
                Logger.i("App moved to BACKGROUND")
                listener?.onBackground()
              }
              else -> Unit
            }
          }
        })
      
        Logger.i("BeaconLifecycle observer registered")
      }
    }

    fun isForeground(): Boolean = isForeground

    fun setListener(
      listener : LifecycleListener
    ){
      this.listener = listener
    }

    interface LifecycleListener  {
      fun onForeground()
      fun onBackground()
    }
}