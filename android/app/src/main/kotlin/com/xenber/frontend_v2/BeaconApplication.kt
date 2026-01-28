package com.xenber.frontend_v2

import android.app.Application
import com.xenber.beaconsdk.BeaconSDK

class BeaconApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        
        // 1. Initialize the SDK Singleton on app launch
        BeaconSDK.init(this)
        
        // 2. The SDK will automatically resume monitoring 
        // if it was active before the app was killed 
        // (logic handled in BeaconSdk.configure)
    }
}