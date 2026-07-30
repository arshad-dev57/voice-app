package com.example.voice_recoginization_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
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
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

class ShakeDetectionService : Service(), SensorEventListener {
    
    companion object {
        private var instance: ShakeDetectionService? = null
        private var methodChannel: MethodChannel? = null
        private const val CHANNEL_ID = "shake_detection_channel"
        private const val NOTIFICATION_ID = 12345
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
        
        fun getInstance(): ShakeDetectionService? = instance
    }
    
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var powerManager: PowerManager? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var vibrator: Vibrator? = null
    
    // Shake detection parameters
    private var lastX = 0f
    private var lastY = 0f
    private var lastZ = 0f
    private var lastShakeTime = 0L
    private val SHAKE_THRESHOLD = 15f // Adjust based on sensitivity needed
    private val SHAKE_COOLDOWN = 2000 // 2 seconds cooldown between shakes
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        
        // Initialize sensor manager
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        
        // Initialize power manager for wake lock
        powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        
        // Initialize vibrator
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        
        // Create notification channel
        createNotificationChannel()
        
        // Start foreground service
        startForeground(NOTIFICATION_ID, createNotification())
        
        // Register accelerometer listener
        sensorManager?.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_NORMAL)
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        sensorManager?.unregisterListener(this)
        releaseWakeLock()
        instance = null
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Shake Detection Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background service for shake detection"
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Voice Assistant Active")
            .setContentText("Shake phone to activate voice assistant")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    override fun onSensorChanged(event: SensorEvent?) {
        event?.let {
            if (it.sensor.type == Sensor.TYPE_ACCELEROMETER) {
                val x = it.values[0]
                val y = it.values[1]
                val z = it.values[2]
                
                val currentTime = System.currentTimeMillis()
                
                // Check if enough time has passed since last shake
                if (currentTime - lastShakeTime > SHAKE_COOLDOWN) {
                    val deltaX = Math.abs(x - lastX)
                    val deltaY = Math.abs(y - lastY)
                    val deltaZ = Math.abs(z - lastZ)
                    
                    // Calculate total acceleration change
                    val deltaTotal = deltaX + deltaY + deltaZ
                    
                    if (deltaTotal > SHAKE_THRESHOLD) {
                        lastShakeTime = currentTime
                        onShakeDetected()
                    }
                }
                
                lastX = x
                lastY = y
                lastZ = z
            }
        }
    }
    
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Not needed for shake detection
    }
    
    private fun onShakeDetected() {
        // Acquire wake lock to keep device awake briefly
        acquireWakeLock()
        
        // Vibrate to indicate shake detected
        vibrator?.vibrate(200)
        
        // Check if app is in background by trying to communicate with Flutter
        // If method channel is not available, launch the app to foreground
        if (methodChannel != null) {
            try {
                // Try to notify Flutter - if this works, app is active
                methodChannel?.invokeMethod("onShakeDetected", null)
            } catch (e: Exception) {
                // If communication fails, app is likely in background
                // Launch the app to foreground
                launchAppToForeground()
            }
        } else {
            // No method channel available, launch app
            launchAppToForeground()
        }
    }
    
    private fun launchAppToForeground() {
        try {
            // Create intent to launch MainActivity with shake flag
            val intent = applicationContext.packageManager.getLaunchIntentForPackage(applicationContext.packageName)
            intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            intent?.putExtra("launched_from_shake", true)
            applicationContext.startActivity(intent)
        } catch (e: Exception) {
            // Log error but don't crash
            android.util.Log.e("ShakeDetectionService", "Failed to launch app: ${e.message}")
        }
    }
    
    private fun acquireWakeLock() {
        if (wakeLock == null || !wakeLock!!.isHeld) {
            wakeLock = powerManager?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "voice_assistant:shake_detection"
            )
            wakeLock?.acquire(5000) // Keep awake for 5 seconds
        }
    }
    
    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }
}
