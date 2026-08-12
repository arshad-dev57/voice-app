package com.example.voice_recoginization_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Restarts shake detection after reboot or app update so the assistant
 * stays available for blind users without opening the app first.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != Intent.ACTION_QUICKBOOT_POWERON
        ) {
            return
        }

        Log.d("BootReceiver", "Restarting ShakeDetectionService after $action")
        val service = Intent(context, ShakeDetectionService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(service)
            } else {
                context.startService(service)
            }
        } catch (e: Exception) {
            Log.e("BootReceiver", "Failed to start ShakeDetectionService: ${e.message}")
        }
    }
}
