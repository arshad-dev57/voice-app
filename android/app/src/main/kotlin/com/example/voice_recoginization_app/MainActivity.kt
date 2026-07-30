package com.example.voice_recoginization_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ACCESSIBILITY_CHANNEL = "com.example.voice_recoginization_app/accessibility"
    private val SHAKE_CHANNEL = "com.example.voice_recoginization_app/shake"
    private val ALARM_CHANNEL = "com.example.voice_recoginization_app/alarm"
    
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if launched from shake detection
        val launchedFromShake = intent.getBooleanExtra("launched_from_shake", false)
        if (launchedFromShake) {
            // Clear the flag to prevent re-triggering
            intent.removeExtra("launched_from_shake")
            
            // Post to ensure Flutter engine is ready
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                notifyFlutterAboutShake()
            }, 500)
        }
    }
    
    private fun notifyFlutterAboutShake() {
        // Notify Flutter that shake was detected and app was launched
        val flutterEngine = flutterEngine
        if (flutterEngine != null) {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHAKE_CHANNEL)
                .invokeMethod("onShakeDetected", null)
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Accessibility service channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL).setMethodCallHandler { call, result ->
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
                    val isEnabled = SimSelectionAccessibilityService.getInstance() != null
                    result.success(isEnabled)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Shake detection channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHAKE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startShakeDetection" -> {
                    startShakeDetectionService()
                    result.success(true)
                }
                "stopShakeDetection" -> {
                    stopShakeDetectionService()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Alarm service channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openSystemAlarmApp" -> {
                    openSystemAlarmApp()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Set the method channel in the accessibility service
        SimSelectionAccessibilityService.setMethodChannel(
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL)
        )
        
        // Set the method channel in the shake detection service
        ShakeDetectionService.setMethodChannel(
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHAKE_CHANNEL)
        )
    }
    
    private fun startShakeDetectionService() {
        val intent = Intent(this, ShakeDetectionService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
    
    private fun stopShakeDetectionService() {
        val intent = Intent(this, ShakeDetectionService::class.java)
        stopService(intent)
    }
    
    private fun openSystemAlarmApp() {
        try {
            val intent = Intent(Intent.ACTION_MAIN)
            intent.addCategory(Intent.CATEGORY_LAUNCHER)
            intent.setClassName("com.android.deskclock", "com.android.deskclock.DeskClock")
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback: try to open any alarm/clock app
            val intent = Intent(Intent.ACTION_VIEW)
            intent.data = Uri.parse("alarm:")
            startActivity(intent)
        }
    }
}
