package com.example.voice_recoginization_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // ------------------------------------------------------------------ //
    //  Channel names — must exactly match the Dart side                    //
    // ------------------------------------------------------------------ //
    private val ACCESSIBILITY_CHANNEL = "com.example.voice_recoginization_app/accessibility"
    private val SHAKE_CHANNEL         = "com.example.voice_recoginization_app/shake"
    private val ALARM_CHANNEL         = "com.example.voice_recoginization_app/alarm"
    private val PHONE_CHANNEL         = "com.example.voice_recoginization_app/phone"

    private var shakeMethodChannel: MethodChannel? = null

    // ------------------------------------------------------------------ //
    //  Activity lifecycle                                                   //
    // ------------------------------------------------------------------ //

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShakeLaunchIntent(intent)
    }

    /**
     * Called when the activity is already running and a new Intent arrives
     * (e.g., ShakeDetectionService re-launches via FLAG_ACTIVITY_SINGLE_TOP).
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShakeLaunchIntent(intent)
    }

    // ------------------------------------------------------------------ //
    //  Flutter engine configuration                                         //
    // ------------------------------------------------------------------ //

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // -------- Accessibility service channel -------- //
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setTargetSim" -> {
                        val simName = call.argument<String>("simName")
                        if (simName != null) {
                            SimSelectionAccessibilityService.setTargetSim(simName)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "simName is required", null)
                        }
                    }
                    "isAccessibilityServiceEnabled" -> {
                        result.success(SimSelectionAccessibilityService.getInstance() != null)
                    }
                    else -> result.notImplemented()
                }
            }

        // -------- Shake detection channel -------- //
        shakeMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, SHAKE_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "startShakeDetection" -> {
                        startShakeDetectionService()
                        result.success(true)
                    }
                    "stopShakeDetection" -> {
                        stopShakeDetectionService()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // -------- Alarm channel -------- //
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openSystemAlarmApp" -> {
                        openSystemAlarmApp()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // -------- Phone channel (native call fallback) -------- //
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PHONE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "makeCall" -> {
                        val number = call.argument<String>("number")
                        if (!number.isNullOrBlank()) {
                            launchCallIntent(number)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "phone number is required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Register static channels in companion objects
        SimSelectionAccessibilityService.setMethodChannel(
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL)
        )
        ShakeDetectionService.setMethodChannel(
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHAKE_CHANNEL)
        )
    }

    // ------------------------------------------------------------------ //
    //  Shake launch handling                                                //
    // ------------------------------------------------------------------ //

    private fun handleShakeLaunchIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("launched_from_shake", false) == true) {
            intent.removeExtra("launched_from_shake")
            // Give the Flutter engine time to initialize before invoking the method
            Handler(Looper.getMainLooper()).postDelayed({
                notifyFlutterAboutShake()
            }, 600)
        }
    }

    private fun notifyFlutterAboutShake() {
        val channel = shakeMethodChannel
            ?: flutterEngine?.let {
                MethodChannel(it.dartExecutor.binaryMessenger, SHAKE_CHANNEL)
            }
        channel?.invokeMethod("onShakeDetected", null)
    }

    // ------------------------------------------------------------------ //
    //  Service management                                                   //
    // ------------------------------------------------------------------ //

    private fun startShakeDetectionService() {
        val intent = Intent(this, ShakeDetectionService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        android.util.Log.d("MainActivity", "ShakeDetectionService started")
    }

    private fun stopShakeDetectionService() {
        stopService(Intent(this, ShakeDetectionService::class.java))
    }

    // ------------------------------------------------------------------ //
    //  Native phone call (used as additional fallback)                      //
    // ------------------------------------------------------------------ //

    private fun launchCallIntent(phoneNumber: String) {
        try {
            val sanitized = phoneNumber.replace(Regex("[^\\d+]"), "")
            val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$sanitized"))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback: open dialer pre-filled (no CALL_PHONE permission required)
            try {
                val sanitized = phoneNumber.replace(Regex("[^\\d+]"), "")
                val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$sanitized"))
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            } catch (ex: Exception) {
                android.util.Log.e("MainActivity", "Both CALL and DIAL failed: ${ex.message}")
            }
        }
    }

    // ------------------------------------------------------------------ //
    //  Alarm app                                                            //
    // ------------------------------------------------------------------ //

    private fun openSystemAlarmApp() {
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
                setClassName("com.android.deskclock", "com.android.deskclock.DeskClock")
            }
            startActivity(intent)
        } catch (e: Exception) {
            try {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("alarm:")))
            } catch (ex: Exception) {
                android.util.Log.e("MainActivity", "Could not open alarm app: ${ex.message}")
            }
        }
    }
}
