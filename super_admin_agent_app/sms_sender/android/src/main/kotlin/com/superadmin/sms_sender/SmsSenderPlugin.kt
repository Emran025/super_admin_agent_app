package com.superadmin.sms_sender

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.telephony.SubscriptionInfo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.UUID

class SmsSenderPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.superadmin.agent/sms_sender")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "sendSms") {
            val recipient = call.argument<String>("recipient")
            val body = call.argument<String>("body")
            val simSlot = call.argument<String>("sim_slot")

            if (recipient != null && body != null) {
                sendSms(recipient, body, simSlot, result)
            } else {
                result.error("INVALID_ARGUMENTS", "Recipient or body is null", null)
            }
        } else {
            result.notImplemented()
        }
    }

    private fun getSmsManager(simSlot: String?): SmsManager {
        @Suppress("DEPRECATION")
        val defaultManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
        } else {
            SmsManager.getDefault()
        }

        if (simSlot == null || simSlot.isEmpty() || simSlot.equals("defaultSlot", ignoreCase = true)) {
            return defaultManager
        }

        val slotIndex = when (simSlot.lowercase()) {
            "sim1" -> 0
            "sim2" -> 1
            else -> return defaultManager
        }

        val hasPhoneStatePermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        if (!hasPhoneStatePermission) {
            android.util.Log.w("SmsSenderPlugin", "READ_PHONE_STATE permission not granted. Falling back to default SmsManager.")
            return defaultManager
        }

        try {
            val subscriptionManager = context.getSystemService(SubscriptionManager::class.java)
            if (subscriptionManager != null) {
                val subscriptionInfo = subscriptionManager.getActiveSubscriptionInfoForSimSlotIndex(slotIndex)
                if (subscriptionInfo != null) {
                    val subId = subscriptionInfo.subscriptionId
                    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        defaultManager.createForSubscriptionId(subId)
                    } else {
                        @Suppress("DEPRECATION")
                        SmsManager.getSmsManagerForSubscriptionId(subId)
                    }
                } else {
                    android.util.Log.w("SmsSenderPlugin", "No active subscription info found for slot index $slotIndex. Using default SmsManager.")
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("SmsSenderPlugin", "Error resolving SmsManager for slot $simSlot: ${e.message}. Using default.", e)
        }

        return defaultManager
    }

    private fun sendSms(recipient: String, body: String, simSlot: String?, result: Result) {
        if (recipient.trim().isEmpty() || body.trim().isEmpty()) {
            result.error("INVALID_ARGUMENTS", "Recipient or body is empty", null)
            return
        }

        val hasSendSmsPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.checkSelfPermission(android.Manifest.permission.SEND_SMS) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        if (!hasSendSmsPermission) {
            result.error("PERMISSION_DENIED", "SEND_SMS permission is not granted", null)
            return
        }

        try {
            val smsManager = getSmsManager(simSlot)

            val sentAction = "SMS_SENT_ACTION_" + UUID.randomUUID().toString()
            
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_ONE_SHOT
            }
            
            val sentIntent = PendingIntent.getBroadcast(
                context,
                0,
                Intent(sentAction),
                pendingFlags
            )

            val sentReceiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context?, intent: Intent?) {
                    context.unregisterReceiver(this)
                    when (resultCode) {
                        Activity.RESULT_OK -> result.success("sent")
                        SmsManager.RESULT_ERROR_NO_SERVICE -> result.success("failed_no_service")
                        else -> result.success("failed_generic")
                    }
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(sentReceiver, IntentFilter(sentAction), Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(sentReceiver, IntentFilter(sentAction))
            }

            smsManager.sendTextMessage(recipient, null, body, sentIntent, null)
        } catch (e: Exception) {
            android.util.Log.e("SmsSenderPlugin", "SMS Send Exception: ", e)
            result.error("SMS_SEND_FAILED", e.message, null)
        }
    }
}
