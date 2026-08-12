package com.example.voice_recoginization_app

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.AlarmClock
import android.provider.Telephony
import android.telecom.TelecomManager
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Native Android actions for calling, SMS, and alarms.
 * Used by the voice assistant so blind users never have to tap the dialer or SMS app.
 */
object NativePhoneActions {
    private const val TAG = "NativePhoneActions"

    fun makeCall(context: Context, rawNumber: String, simSlot: Int? = null): Boolean {
        val number = rawNumber.replace(Regex("[^\\d+]"), "")
        if (number.isEmpty()) {
            Log.e(TAG, "makeCall: empty number")
            return false
        }

        val hasCallPermission = ContextCompat.checkSelfPermission(
            context, Manifest.permission.CALL_PHONE
        ) == PackageManager.PERMISSION_GRANTED

        if (hasCallPermission && placeCallViaTelecom(context, number)) {
            return true
        }

        if (hasCallPermission && launchCallIntent(context, number, simSlot)) {
            return true
        }

        return launchDialIntent(context, number)
    }

    private fun placeCallViaTelecom(context: Context, number: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return try {
            val telecom = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                ?: return false
            val uri = Uri.fromParts("tel", number, null)
            val extras = Bundle().apply {
                // Speakerphone helps blind users hear the call without finding the button.
                putBoolean(TelecomManager.EXTRA_START_CALL_WITH_SPEAKERPHONE, true)
            }
            telecom.placeCall(uri, extras)
            Log.d(TAG, "placeCallViaTelecom: $number")
            true
        } catch (e: Exception) {
            Log.e(TAG, "placeCallViaTelecom failed: ${e.message}")
            false
        }
    }

    private fun launchCallIntent(context: Context, number: String, simSlot: Int?): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$number")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                val slot = simSlot ?: 0
                putExtra("com.android.phone.extra.slot", slot)
                putExtra("slot", slot)
                putExtra("simId", slot)
                putExtra("sim_slot", slot)
                putExtra("android.telecom.extra.START_CALL_WITH_SPEAKERPHONE", true)
            }
            context.startActivity(intent)
            Log.d(TAG, "ACTION_CALL launched for $number")
            true
        } catch (e: Exception) {
            Log.e(TAG, "ACTION_CALL failed: ${e.message}")
            false
        }
    }

    private fun launchDialIntent(context: Context, number: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            Log.d(TAG, "ACTION_DIAL launched for $number")
            true
        } catch (e: Exception) {
            Log.e(TAG, "ACTION_DIAL failed: ${e.message}")
            false
        }
    }

    /**
     * Sends a real Android SMS via the system SmsManager so it appears in the
     * phone's Messages app (Google Messages / Samsung Messages) — same idea as
     * placing a call through the system Phone app. Then opens that thread.
     */
    fun sendSms(context: Context, rawNumber: String, message: String): Boolean {
        val number = rawNumber.replace(Regex("[^\\d+]"), "")
        if (number.isEmpty() || message.isBlank()) {
            Log.e(TAG, "sendSms: empty number or message")
            return false
        }

        val hasSmsPermission = ContextCompat.checkSelfPermission(
            context, Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED

        val sent = hasSmsPermission && sendViaSmsManager(context, number, message)
        if (sent) {
            openSystemSmsThread(context, number)
            return true
        }

        // Last resort: open the system Messages composer pre-filled.
        return openSmsComposer(context, number, message)
    }

    private fun sendViaSmsManager(context: Context, number: String, message: String): Boolean {
        return try {
            val smsManager = resolveSmsManager(context)
            val parts = smsManager.divideMessage(message)
            if (parts.size <= 1) {
                smsManager.sendTextMessage(number, null, message, null, null)
            } else {
                smsManager.sendMultipartTextMessage(number, null, parts, null, null)
            }
            Log.d(TAG, "System SMS sent to $number (${parts.size} parts)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "SmsManager send failed: ${e.message}")
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun resolveSmsManager(context: Context): SmsManager {
        val subId = try {
            SmsManager.getDefaultSmsSubscriptionId()
        } catch (_: Exception) {
            SubscriptionManager.INVALID_SUBSCRIPTION_ID
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val mgr = context.getSystemService(SmsManager::class.java)
                ?: SmsManager.getDefault()
            if (subId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
                mgr.createForSubscriptionId(subId)
            } else {
                mgr
            }
        } else if (subId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
            SmsManager.getSmsManagerForSubscriptionId(subId)
        } else {
            SmsManager.getDefault()
        }
    }

    /** Opens the system Messages app conversation for [number]. */
    fun openSystemSmsThread(context: Context, number: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("sms:$number")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                defaultSmsPackage(context)?.let { setPackage(it) }
            }
            context.startActivity(intent)
            Log.d(TAG, "Opened system Messages thread for $number")
            true
        } catch (e: Exception) {
            Log.e(TAG, "openSystemSmsThread failed: ${e.message}")
            openSystemMessagesApp(context)
        }
    }

    /** Opens the phone's default Messages app (not the in-app chat). */
    fun openSystemMessagesApp(context: Context): Boolean {
        return try {
            val pkg = defaultSmsPackage(context)
            val launch = if (!pkg.isNullOrBlank()) {
                context.packageManager.getLaunchIntentForPackage(pkg)
            } else {
                null
            }
            val intent = launch ?: Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_APP_MESSAGING)
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "openSystemMessagesApp failed: ${e.message}")
            false
        }
    }

    private fun defaultSmsPackage(context: Context): String? {
        return try {
            Telephony.Sms.getDefaultSmsPackage(context)
        } catch (_: Exception) {
            null
        }
    }

    private fun openSmsComposer(context: Context, number: String, message: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$number")).apply {
                putExtra("sms_body", message)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                defaultSmsPackage(context)?.let { setPackage(it) }
            }
            context.startActivity(intent)
            Log.d(TAG, "System SMS composer opened for $number")
            true
        } catch (e: Exception) {
            Log.e(TAG, "SMS composer failed: ${e.message}")
            false
        }
    }

    fun setAlarm(context: Context, hour: Int, minute: Int, label: String): Boolean {
        return try {
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                putExtra(AlarmClock.EXTRA_MESSAGE, label)
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                putExtra(AlarmClock.EXTRA_VIBRATE, true)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            Log.d(TAG, "Alarm set for $hour:$minute")
            true
        } catch (e: Exception) {
            Log.e(TAG, "setAlarm failed: ${e.message}")
            false
        }
    }

    fun requestIgnoreBatteryOptimizations(activity: Activity) {
        try {
            val intent = Intent(
                android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:${activity.packageName}")
            )
            activity.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "battery optimization intent failed: ${e.message}")
            try {
                activity.startActivity(
                    Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                )
            } catch (ex: Exception) {
                Log.e(TAG, "battery settings fallback failed: ${ex.message}")
            }
        }
    }

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        return try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            pm.isIgnoringBatteryOptimizations(context.packageName)
        } catch (e: Exception) {
            false
        }
    }
}
