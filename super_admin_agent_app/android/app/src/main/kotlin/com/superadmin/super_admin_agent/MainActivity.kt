package com.superadmin.super_admin_agent

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.os.Bundle
import android.provider.Telephony
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Main activity for the Super Admin Agent app.
 *
 * In addition to standard Flutter setup, this activity:
 *  - Creates the notification channel for the background service.
 *  - Exposes a MethodChannel "com.superadmin.agent/app_control" to Flutter
 *    for querying / requesting the Default SMS App role.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.superadmin.agent/app_control"
        private const val SMS_INBOX_CHANNEL = "com.superadmin.agent/sms_inbox"
        private const val SMS_INBOX_EVENTS = "com.superadmin.agent/sms_inbox_events"
        private const val REQUEST_DEFAULT_SMS_APP = 1001
    }

    // Pending Flutter result while we wait for the role-request result
    private var pendingDefaultSmsResult: MethodChannel.Result? = null
    private var smsContentObserver: ContentObserver? = null
    private var smsInboxEventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        setupAppControlChannel()
        setupSmsInboxChannel()
        setupSmsInboxEventChannel()
    }

    override fun onResume() {
        super.onResume()
        registerSmsContentObserver()
    }

    override fun onPause() {
        unregisterSmsContentObserver()
        super.onPause()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Flutter MethodChannel: app_control
    // ─────────────────────────────────────────────────────────────────────────

    private fun setupAppControlChannel() {
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isDefaultSmsApp"     -> result.success(isDefaultSmsApp())
                    "requestDefaultSmsApp" -> requestDefaultSmsApp(result)
                    else                  -> result.notImplemented()
                }
            }
    }

    private fun isDefaultSmsApp(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            roleManager?.isRoleHeld(RoleManager.ROLE_SMS) == true
        } else {
            @Suppress("DEPRECATION")
            Telephony.Sms.getDefaultSmsPackage(this) == packageName
        }
    }

    /**
     * Asks Android to present the "Change default SMS app?" dialog.
     *
     * On Android 10+ (Q) we use the [RoleManager] API.
     * On Android 4.4–9 we use the legacy [Telephony.Sms.ACTION_CHANGE_DEFAULT] intent.
     *
     * The result ("already_default" | "granted" | "denied") is returned to Flutter
     * once [onActivityResult] fires.
     */
    private fun requestDefaultSmsApp(result: MethodChannel.Result) {
        if (isDefaultSmsApp()) {
            Log.d(TAG, "Already the default SMS app.")
            result.success("already_default")
            return
        }

        pendingDefaultSmsResult = result

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(RoleManager::class.java)
                val intent = roleManager!!.createRequestRoleIntent(RoleManager.ROLE_SMS)
                startActivityForResult(intent, REQUEST_DEFAULT_SMS_APP)
            } else {
                @Suppress("DEPRECATION")
                val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT).apply {
                    putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
                }
                startActivityForResult(intent, REQUEST_DEFAULT_SMS_APP)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request Default SMS role: ${e.message}", e)
            pendingDefaultSmsResult?.error("ROLE_REQUEST_FAILED", e.message, null)
            pendingDefaultSmsResult = null
        }
    }

    @Deprecated("Using for compatibility with pre-Android-10 flow")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_DEFAULT_SMS_APP) {
            val granted = isDefaultSmsApp()
            Log.d(TAG, "Default SMS App result: granted=$granted")
            pendingDefaultSmsResult?.success(if (granted) "granted" else "denied")
            pendingDefaultSmsResult = null
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Flutter MethodChannel: sms_inbox (compensating Chats UI only)
    // ─────────────────────────────────────────────────────────────────────────

    private fun setupSmsInboxChannel() {
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, SMS_INBOX_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getConversations" -> {
                        try {
                            val conversations = SmsInboxBridge.getConversations(this)
                            result.success(conversations)
                        } catch (e: SecurityException) {
                            Log.e(TAG, "getConversations: permission denied", e)
                            result.error("PERMISSION_DENIED", e.message, null)
                        } catch (e: Exception) {
                            Log.e(TAG, "getConversations failed", e)
                            result.error("QUERY_FAILED", e.message, null)
                        }
                    }
                    "getMessages" -> {
                        val threadId = call.argument<Number>("threadId")?.toLong()
                        if (threadId == null) {
                            result.error("INVALID_ARGUMENTS", "threadId required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(SmsInboxBridge.getMessages(this, threadId))
                        } catch (e: SecurityException) {
                            result.error("PERMISSION_DENIED", e.message, null)
                        } catch (e: Exception) {
                            result.error("QUERY_FAILED", e.message, null)
                        }
                    }
                    "markThreadAsRead" -> {
                        val threadId = call.argument<Number>("threadId")?.toLong()
                        if (threadId == null) {
                            result.error("INVALID_ARGUMENTS", "threadId required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            SmsInboxBridge.markThreadAsRead(this, threadId)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UPDATE_FAILED", e.message, null)
                        }
                    }
                    "sendMessage" -> {
                        val address = call.argument<String>("address")
                        val body = call.argument<String>("body")
                        if (address.isNullOrBlank() || body.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENTS", "address and body required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(UserSmsMessenger.sendMessage(this, address, body))
                        } catch (e: SecurityException) {
                            result.error("PERMISSION_DENIED", e.message, null)
                        } catch (e: Exception) {
                            result.error("SEND_FAILED", e.message, null)
                        }
                    }
                    "retryMessage" -> {
                        val messageId = call.argument<Number>("messageId")?.toLong()
                        if (messageId == null) {
                            result.error("INVALID_ARGUMENTS", "messageId required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(UserSmsMessenger.retryMessage(this, messageId))
                        } catch (e: Exception) {
                            result.error("RETRY_FAILED", e.message, null)
                        }
                    }
                    "deleteMessage" -> {
                        val messageId = call.argument<Number>("messageId")?.toLong()
                        if (messageId == null) {
                            result.error("INVALID_ARGUMENTS", "messageId required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(UserSmsMessenger.deleteMessage(this, messageId))
                        } catch (e: Exception) {
                            result.error("DELETE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setupSmsInboxEventChannel() {
        EventChannel(flutterEngine!!.dartExecutor.binaryMessenger, SMS_INBOX_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsInboxEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    smsInboxEventSink = null
                }
            })
    }

    private fun registerSmsContentObserver() {
        if (smsContentObserver != null) return
        smsContentObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                smsInboxEventSink?.success("changed")
            }
        }
        contentResolver.registerContentObserver(
            Uri.parse("content://sms"),
            true,
            smsContentObserver!!,
        )
    }

    private fun unregisterSmsContentObserver() {
        smsContentObserver?.let { contentResolver.unregisterContentObserver(it) }
        smsContentObserver = null
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Notification channel
    // ─────────────────────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "super_admin_agent",
                "Super Admin Agent Channel",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Persistent notification for Super Admin Agent"
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }
}
