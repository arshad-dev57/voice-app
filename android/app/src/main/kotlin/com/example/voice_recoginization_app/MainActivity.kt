package com.example.voice_recoginization_app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val ACCESSIBILITY_CHANNEL = "com.example.voice_recoginization_app/accessibility"
    private val SHAKE_CHANNEL = "com.example.voice_recoginization_app/shake"
    private val ALARM_CHANNEL = "com.example.voice_recoginization_app/alarm"
    private val PHONE_CHANNEL = "com.example.voice_recoginization_app/phone"

    private var shakeMethodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableShowWhenLocked()
        handleShakeLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        enableShowWhenLocked()
        handleShakeLaunchIntent(intent)
    }

    private fun enableShowWhenLocked() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openSystemAlarmApp" -> {
                        openSystemAlarmApp()
                        result.success(true)
                    }
                    "setAlarm" -> {
                        val hour = call.argument<Int>("hour") ?: 0
                        val minute = call.argument<Int>("minute") ?: 0
                        val label = call.argument<String>("label") ?: "Voice Alarm"
                        result.success(NativePhoneActions.setAlarm(this, hour, minute, label))
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PHONE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "makeCall" -> {
                        val number = call.argument<String>("number")
                        val simSlot = call.argument<Int>("simSlot")
                        if (!number.isNullOrBlank()) {
                            result.success(NativePhoneActions.makeCall(this, number, simSlot))
                        } else {
                            result.error("INVALID_ARGUMENT", "phone number is required", null)
                        }
                    }
                    "sendSms" -> {
                        val number = call.argument<String>("number")
                        val message = call.argument<String>("message")
                        if (!number.isNullOrBlank() && !message.isNullOrBlank()) {
                            result.success(NativePhoneActions.sendSms(this, number, message))
                        } else {
                            result.error("INVALID_ARGUMENT", "number and message are required", null)
                        }
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        NativePhoneActions.requestIgnoreBatteryOptimizations(this)
                        result.success(true)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        result.success(NativePhoneActions.isIgnoringBatteryOptimizations(this))
                    }
                    else -> result.notImplemented()
                }
            }

        SimSelectionAccessibilityService.setMethodChannel(
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL)
        )
        ShakeDetectionService.setMethodChannel(
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHAKE_CHANNEL)
        )
    }

    private fun handleShakeLaunchIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("launched_from_shake", false) == true) {
            intent.removeExtra("launched_from_shake")
            Handler(Looper.getMainLooper()).postDelayed({
                notifyFlutterAboutShake()
            }, 400)
        }
    }

    private fun notifyFlutterAboutShake() {
        val channel = shakeMethodChannel
            ?: flutterEngine?.let {
                MethodChannel(it.dartExecutor.binaryMessenger, SHAKE_CHANNEL)
            }
        channel?.invokeMethod("onShakeDetected", null)
    }

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

    private fun openSystemAlarmApp() {
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
                setClassName("com.android.deskclock", "com.android.deskclock.DeskClock")
            }
            startActivity(intent)
        } catch (e: Exception) {
            NativePhoneActions.setAlarm(this, 7, 0, "Voice Alarm")
        }
    }
}
