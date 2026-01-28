package com.xenber.beaconsdk.core

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.xenber.beaconsdk.util.Logger

class RawBleScanner(
    context: Context,
    private val onBatteryDetected: (mac: String, battery: Int) -> Unit
) {

    private val bluetoothManager =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter
    private val handler = Handler(Looper.getMainLooper())

    private var scanner: BluetoothLeScanner? = null
    private var scanning = false

    private val scanCallback = object : ScanCallback() {

        override fun onScanResult(callbackType: Int, result: ScanResult) {
            handleResult(result)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach { handleResult(it) }
        }

        override fun onScanFailed(errorCode: Int) {
            Logger.i("RawBleScanner scan failed: $errorCode")
        }
    }

    fun startScan() {
        if (scanning) return
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            Logger.i("Bluetooth disabled, RawBleScanner not started")
            return
        }

        scanner = bluetoothAdapter.bluetoothLeScanner
        if (scanner == null) {
            Logger.i("BluetoothLeScanner unavailable")
            return
        }

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setMatchMode(ScanSettings.MATCH_MODE_STICKY)
            .build()

        scanner?.startScan(emptyList(), settings, scanCallback)
        scanning = true

        Logger.i("RawBleScanner started")
    }

    fun stopScan() {
        if (!scanning) return
        scanner?.stopScan(scanCallback)
        scanning = false
        Logger.i("RawBleScanner stopped")
    }

    private fun handleResult(result: ScanResult) {
        val record = result.scanRecord ?: return
        val serviceData = record.serviceData ?: return

        serviceData.forEach { (uuid, bytes) ->
            if (uuid.uuid.toString().contains("5242", ignoreCase = true)) {
                if (bytes.size > 1) {
                    val battery = bytes[1].toInt() and 0xFF
                    val mac = result.device.address.uppercase()

                    Logger.i("🔋 Battery $battery% from $mac (serviceData)")
                    onBatteryDetected(mac, battery)
                }
            }
        }
    }
}
