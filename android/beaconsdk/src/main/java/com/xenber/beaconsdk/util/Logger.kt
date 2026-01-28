package com.xenber.beaconsdk.util

import android.util.Log

object Logger {
    private const val TAG = "BeaconSdk"

    fun i(message: String) {
        Log.i(TAG, message)
    }

    fun e(message: String, t: Throwable? = null) {
        if (t != null) {
            Log.e(TAG, message, t)
        } else {
            Log.e(TAG, message)
        }
    }
    
    fun d(message: String) {
        Log.d(TAG, message)
    }
}