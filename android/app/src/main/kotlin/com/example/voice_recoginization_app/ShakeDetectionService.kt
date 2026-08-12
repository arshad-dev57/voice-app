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
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sqrt

/**
 * Foreground service that listens for a deliberate phone shake.
 *
 * On shake it:
 *  1. Vibrates (haptic cue for blind users)
 *  2. Wakes the screen
 *  3. Brings the app to the foreground via a full-screen intent (Android 10+ safe)
 *  4. Notifies Flutter so the assistant greets and starts listening
 */
class ShakeDetectionService : Service(), SensorEventListener {

    companion object {
        private var instance: ShakeDetectionService? = null
        private var methodChannel: MethodChannel? = null

        private const val TAG = "ShakeDetectionService"
        private const val CHANNEL_ID = "shake_detection_channel"
        private const val WAKE_CHANNEL_ID = "shake_wake_channel"
        private const val NOTIFICATION_ID = 12345
        private const val WAKE_NOTIFICATION_ID = 12346

        private const val SHAKE_THRESHOLD_M_S2 = 18.0f
        private const val SHAKE_COOLDOWN_MS = 2500L

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

    override fun onCreate() {
        super.onCreate()
        instance = this

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager

        createNotificationChannels()
        startForeground(NOTIFICATION_ID, createPersistentNotification())

        sensorManager?.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI)
        Log.d(TAG, "Service started, listening for shakes")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (instance == null) instance = this
        if (sensorManager == null) {
            sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            sensorManager?.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI)
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        sensorManager?.unregisterListener(this)
        releaseWakeLock()
        instance = null
        Log.d(TAG, "Service destroyed — requesting restart")
        // Ask the OS to bring us back; START_STICKY also covers this.
        try {
            val restart = Intent(applicationContext, ShakeDetectionService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(restart)
            } else {
                applicationContext.startService(restart)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Restart from onDestroy failed: ${e.message}")
        }
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        try {
            val restart = Intent(applicationContext, ShakeDetectionService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(restart)
            } else {
                applicationContext.startService(restart)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Restart from onTaskRemoved failed: ${e.message}")
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        event ?: return
        if (event.sensor.type != Sensor.TYPE_ACCELEROMETER) return

        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        val magnitude = sqrt(x * x + y * y + z * z)
        val now = System.currentTimeMillis()

        if (magnitude > SHAKE_THRESHOLD_M_S2 && (now - lastShakeTime) > SHAKE_COOLDOWN_MS) {
            lastShakeTime = now
            Log.d(TAG, "Shake detected magnitude=$magnitude")
            onShakeDetected()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun onShakeDetected() {
        acquireWakeLock()
        vibrate()
        bringAppToForeground()
        notifyFlutter()
    }

    /**
     * Android 10+ blocks startActivity from the background. A foreground
     * service + full-screen intent notification is the supported way to
     * wake the assistant like an alarm or incoming call.
     */
    private fun bringAppToForeground() {
        val launchIntent = buildLaunchIntent()
        val pending = PendingIntent.getActivity(
            this,
            1,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val wakeNotification = NotificationCompat.Builder(this, WAKE_CHANNEL_ID)
            .setContentTitle("Voice Assistant")
            .setContentText("Listening — tell me what you want to do")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .setFullScreenIntent(pending, true)
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(WAKE_NOTIFICATION_ID, wakeNotification)

        // Also try a direct launch. This succeeds when the app process is
        // already considered in the foreground (FGS + recent user interaction).
        try {
            startActivity(launchIntent)
            Log.d(TAG, "startActivity launched MainActivity")
        } catch (e: Exception) {
            Log.w(TAG, "Direct startActivity blocked: ${e.message}")
        }
    }

    private fun buildLaunchIntent(): Intent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
        )
        intent.putExtra("launched_from_shake", true)
        return intent
    }

    private fun notifyFlutter() {
        val channel = methodChannel ?: return
        try {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                try {
                    channel.invokeMethod("onShakeDetected", null)
                } catch (e: Exception) {
                    Log.e(TAG, "Method channel invoke failed: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "notifyFlutter failed: ${e.message}")
        }
    }

    private fun vibrate() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                manager.defaultVibrator.vibrate(
                    VibrationEffect.createWaveform(longArrayOf(0, 120, 80, 120), -1)
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                vibrator.vibrate(
                    VibrationEffect.createWaveform(longArrayOf(0, 120, 80, 120), -1)
                )
            } else {
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                @Suppress("DEPRECATION")
                vibrator.vibrate(200)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Vibration failed: ${e.message}")
        }
    }

    @Suppress("DEPRECATION")
    private fun acquireWakeLock() {
        if (wakeLock == null || wakeLock?.isHeld != true) {
            wakeLock = powerManager?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "voice_assistant::shake_wake_lock"
            )
            wakeLock?.acquire(8_000L)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Voice Assistant",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Running in background — shake to activate"
                setShowBadge(false)
            }
        )

        nm.createNotificationChannel(
            NotificationChannel(
                WAKE_CHANNEL_ID,
                "Assistant Wake",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Wakes the assistant when you shake the phone"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(true)
            }
        )
    }

    private fun createPersistentNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Voice Assistant Active")
            .setContentText("Shake your phone and tell me what to do")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
