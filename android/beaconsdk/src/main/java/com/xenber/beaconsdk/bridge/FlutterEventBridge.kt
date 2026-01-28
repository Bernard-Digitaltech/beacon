package com.xenber.beaconsdk.bridge

import android.os.Handler
import android.os.Looper
import com.xenber.beaconsdk.util.Logger

class FlutterEventBridge {
    
    private var listener: ((Map<String, Any?>) -> Unit)? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun setAndroidListener(listener: ((Map<String, Any?>) -> Unit)?) {
        this.listener = listener
        Logger.i("FlutterEventBridge listener attached: ${listener != null}")
    }

    fun clear() {
        listener = null
        Logger.i("FlutterEventBridge cleared")
    }

    fun send(data: Map<String, Any?>) {
        mainHandler.post {
            try {
                listener?.invoke(data)
            } catch (e: Exception) {
                Logger.e("FlutterEventBridge send failed: ${e.message}")
            }
        }
    }
}
