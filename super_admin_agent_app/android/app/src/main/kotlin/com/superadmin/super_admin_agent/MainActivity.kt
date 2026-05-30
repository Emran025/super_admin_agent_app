package com.superadmin.super_admin_agent

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Telephony
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
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
        private const val REQUEST_DEFAULT_SMS_APP = 1001
    }

    // Pending Flutter result while we wait for the role-request result
    private var pendingDefaultSmsResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        setupAppControlChannel()
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
