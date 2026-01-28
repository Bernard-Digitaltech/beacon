package com.xenber.beaconsdk.notification

import android.app.NotificationManager
import android.app.NotificationChannel
import android.os.Build
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.app.NotificationCompat
// import com.xenber.beaconsdk.R
import com.xenber.beaconsdk.util.Logger
import org.json.JSONObject

object NotificationFactory {

    private const val ALERT_CHANNEL = "beacon_detection_alert"
    private const val EXTERNAL_TRIGGER_NOTI_ID = 1001

    // fun triggerExternalApp(
    //     context: Context,
    //     mac: String,
    //     targetApp: String,
    //     params: JSONObject
    // ) {
    //     try {
    //         val uriBuilder = Uri.parse(targetApp).buildUpon()
    //         params.keys().forEach {
    //             uriBuilder.appendQueryParameter(it, params.get(it).toString())
    //         }

    //         val intent = Intent(Intent.ACTION_VIEW, uriBuilder.build()).apply {
    //             flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    //         }

    //         val pi = PendingIntent.getActivity(
    //             context,
    //             mac.hashCode(),
    //             intent,
    //             PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    //         )

    //         val notification = NotificationCompat.Builder(context, ALERT_CHANNEL)
    //             .setSmallIcon(android.R.drawable.ic_dialog_info)
    //             .setContentTitle(" Nearby: ${params.optString("loc")}")
    //             .setContentText("Tap to check-in for ${params.optString("shift")} shift")
    //             .setPriority(NotificationCompat.PRIORITY_MAX)
    //             .setContentIntent(pi)
    //             .setAutoCancel(true)
    //             .build()

    //         val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    //         nm.notify(EXTERNAL_TRIGGER_NOTI_ID, notification)

    //     } catch (e: Exception) {
    //         Logger.e("Trigger failed: ${e.message}")
    //     }
    // }

    fun showInternalNotification(
        context: Context,
        mac: String,
        params: JSONObject
    ){
        try {
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    ALERT_CHANNEL,
                    "Beacon Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                description = "Beacons Detected "
            }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent =
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: run {
                    Logger.e("SDK Error: Could not resolve host app Launcher Activity.")
                    return
                }

            launchIntent.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("action", "beacon_detected")
                putExtra("mac_address", mac)
                putExtra("location_name", params.optString("loc", "Unknown Location"))
                putExtra("rssi", params.optInt("rssi", 0))
                putExtra("timestamp", params.optLong("timestamp", 0L))
            }

            val pi = PendingIntent.getActivity(
                context,
                mac.hashCode(),
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(context, ALERT_CHANNEL)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(" Nearby: ${params.optString("loc", "Unknown Location")}")
                .setContentText("Tap to check-in for ${params.optString("shift", "your shift")} shift")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setContentIntent(pi)
                .setAutoCancel(true)
                .build()

            notificationManager.notify(mac.hashCode(), notification)

        } catch (e: Exception) {
            Logger.e("Notification failed: ${e.message}")
        }
    }
}
