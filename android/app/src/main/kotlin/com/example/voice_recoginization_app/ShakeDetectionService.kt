package com.example.voice_recoginization_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sqrt

class ShakeDetectionService : Service(), SensorEventListener {

    companion object {
        private var instance: ShakeDetectionService? = null
        private var methodChannel: MethodChannel? = null
        private const val CHANNEL_ID = "shake_detection_channel"
        private const val NOTIFICATION_ID = 12345

        // Shake detection thresholds
        // Uses gravitational magnitude: phone at rest ≈ 9.8 m/s².
        // A deliberate shake produces 20–30 m/s² total acceleration.
        private const val SHAKE_THRESHOLD_M_S2 = 18.0f // minimum acceleration to count as shake
        private const val SHAKE_COOLDOWN_MS = 2000L    // 2 seconds between activations

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }

        fun getInstance(): ShakeDetectionService? = instance
    }

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var powerManager: PowerManager? = null
    private var wakeLock: PowerManager.WakeLock? = null

    private var lastShakeTime = 0L

    // ------------------------------------------------------------------ //
    //  Lifecycle                                                            //
    // ------------------------------------------------------------------ //

    override fun onCreate() {
        super.onCreate()
        instance = this

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())

        // SENSOR_DELAY_UI (~60ms) is more responsive than SENSOR_DELAY_NORMAL (~200ms)
        // while still being battery-friendly for a continuous background service.
        sensorManager?.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI)

        android.util.Log.d("ShakeDetectionService", "Service started, listening for shakes")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // START_STICKY: if the OS kills the service, restart it automatically.
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        sensorManager?.unregisterListener(this)
        releaseWakeLock()
        instance = null
        android.util.Log.d("ShakeDetectionService", "Service destroyed")
    }

    // ------------------------------------------------------------------ //
    //  Sensor events                                                        //
    // ------------------------------------------------------------------ //

    override fun onSensorChanged(event: SensorEvent?) {
        event ?: return
        if (event.sensor.type != Sensor.TYPE_ACCELEROMETER) return

        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]

        // Compute total acceleration magnitude (m/s²).
        // Gravity contributes ~9.8 m/s² at rest; subtracting it gives pure movement.
        val magnitude = sqrt(x * x + y * y + z * z)

        val currentTime = System.currentTimeMillis()

        if (magnitude > SHAKE_THRESHOLD_M_S2 &&
            (currentTime - lastShakeTime) > SHAKE_COOLDOWN_MS) {
            lastShakeTime = currentTime
            android.util.Log.d("ShakeDetectionService", "Shake detected! magnitude=$magnitude")
            onShakeDetected()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Not needed for shake detection
    }

    // ------------------------------------------------------------------ //
    //  Shake response                                                       //
    // ------------------------------------------------------------------ //

    private fun onShakeDetected() {
        acquireWakeLock()
        vibrate()

        // Try to notify Flutter via Method Channel (works when app is in foreground/background).
        // If the channel call fails (app killed), launch the activity instead.
        val channel = methodChannel
        if (channel != null) {
            try {
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    channel.invokeMethod("onShakeDetected", null)
                }
            } catch (e: Exception) {
                android.util.Log.e("ShakeDetectionService", "Method channel invoke failed, launching app: ${e.message}")
                launchAppToForeground()
            }
        } else {
            launchAppToForeground()
        }
    }

    private fun launchAppToForeground() {
        try {
            val pm = applicationContext.packageManager
            val intent = pm.getLaunchIntentForPackage(applicationContext.packageName)
            if (intent != null) {
                intent.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                intent.putExtra("launched_from_shake", true)
                applicationContext.startActivity(intent)
                android.util.Log.d("ShakeDetectionService", "App launched to foreground")
            }
        } catch (e: Exception) {
            android.util.Log.e("ShakeDetectionService", "Failed to launch app: ${e.message}")
        }
    }

    // ------------------------------------------------------------------ //
    //  Vibration (API-safe)                                                 //
    // ------------------------------------------------------------------ //

    private fun vibrate() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // API 31+ — use VibratorManager
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                val vibrator = vibratorManager.defaultVibrator
                vibrator.vibrate(VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE))
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // API 26–30 — use VibrationEffect
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                vibrator.vibrate(VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                // API < 26 — use deprecated method (still valid on old devices)
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                @Suppress("DEPRECATION")
                vibrator.vibrate(200)
            }
        } catch (e: Exception) {
            android.util.Log.e("ShakeDetectionService", "Vibration failed: ${e.message}")
        }
    }

    // ------------------------------------------------------------------ //
    //  Wake lock                                                            //
    // ------------------------------------------------------------------ //

    private fun acquireWakeLock() {
        if (wakeLock == null || !wakeLock!!.isHeld) {
            wakeLock = powerManager?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "voice_assistant::shake_wake_lock"
            )
            // Keep CPU awake for 5 seconds — enough to launch TTS and speech recognition.
            wakeLock?.acquire(5_000L)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    // ------------------------------------------------------------------ //
    //  Notification (required for foreground service)                       //
    // ------------------------------------------------------------------ //

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Voice Assistant",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Running in background — shake to activate"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        // Tap notification to open the app
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Voice Assistant Active")
            .setContentText("Shake your phone to activate")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
