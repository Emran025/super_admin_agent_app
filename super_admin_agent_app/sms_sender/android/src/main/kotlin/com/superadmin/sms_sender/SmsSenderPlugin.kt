package com.superadmin.sms_sender

import android.app.Activity
import android.app.PendingIntent
import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.UUID

class SmsSenderPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.superadmin.agent/sms_sender")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "sendSms" -> {
                val recipient   = call.argument<String>("recipient")
                val body        = call.argument<String>("body")
                val simSlot     = call.argument<String>("sim_slot")
                val customerName = call.argument<String>("customer_name")
                val systemName  = call.argument<String>("system_name")

                android.util.Log.d(
                    TAG,
                    "Received sendSms for recipient=$recipient customer=$customerName system=$systemName"
                )

                if (recipient != null && body != null) {
                    sendSms(recipient, body, simSlot, customerName, systemName, result)
                } else {
                    android.util.Log.e(TAG, "Recipient or body is null")
                    result.error("INVALID_ARGUMENTS", "Recipient or body is null", null)
                }
            }

            "isDefaultSmsApp" -> {
                result.success(isDefaultSmsApp())
            }

            else -> result.notImplemented()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Default SMS App check
    // ─────────────────────────────────────────────────────────────────────────

    private fun isDefaultSmsApp(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = context.getSystemService(RoleManager::class.java)
            roleManager?.isRoleHeld(RoleManager.ROLE_SMS) == true
        } else {
            @Suppress("DEPRECATION")
            Telephony.Sms.getDefaultSmsPackage(context) == context.packageName
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SmsManager resolution
    // ─────────────────────────────────────────────────────────────────────────

    private fun getSmsManager(simSlot: String?): SmsManager {
        @Suppress("DEPRECATION")
        val defaultManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
        } else {
            SmsManager.getDefault()
        }

        val hasPhoneState = hasPermission(android.Manifest.permission.READ_PHONE_STATE)

        // No slot preference → try to auto-resolve when there is exactly 1 active SIM
        if (simSlot.isNullOrEmpty() || simSlot.equals("defaultSlot", ignoreCase = true)) {
            if (hasPhoneState) {
                try {
                    val sm = context.getSystemService(SubscriptionManager::class.java)
                    val active = sm?.activeSubscriptionInfoList
                    if (!active.isNullOrEmpty() && active.size == 1) {
                        val subId = active[0].subscriptionId
                        android.util.Log.d(TAG, "Single SIM detected (subId=$subId). Routing to it.")
                        return smsManagerForSub(defaultManager, subId)
                    }
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "Error resolving single-SIM fallback: ${e.message}", e)
                }
            }
            return defaultManager
        }

        // Named slot
        val slotIndex = when (simSlot.lowercase()) {
            "sim1" -> 0
            "sim2" -> 1
            else   -> return defaultManager
        }

        if (!hasPhoneState) {
            android.util.Log.w(TAG, "READ_PHONE_STATE not granted — using default SmsManager.")
            return defaultManager
        }

        return try {
            val sm   = context.getSystemService(SubscriptionManager::class.java)
            val info = sm?.getActiveSubscriptionInfoForSimSlotIndex(slotIndex)
            if (info != null) {
                smsManagerForSub(defaultManager, info.subscriptionId)
            } else {
                android.util.Log.w(TAG, "No active SIM on slot $slotIndex — using default.")
                defaultManager
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error resolving SIM slot $simSlot: ${e.message}. Using default.", e)
            defaultManager
        }
    }

    private fun smsManagerForSub(defaultManager: SmsManager, subId: Int): SmsManager {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            defaultManager.createForSubscriptionId(subId)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getSmsManagerForSubscriptionId(subId)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SMS dispatch
    // ─────────────────────────────────────────────────────────────────────────

    private fun sendSms(
        recipient: String,
        body: String,
        simSlot: String?,
        customerName: String?,
        systemName: String?,
        result: Result,
    ) {
        if (recipient.isBlank() || body.isBlank()) {
            result.error("INVALID_ARGUMENTS", "Recipient or body is empty", null)
            return
        }

        if (!hasPermission(android.Manifest.permission.SEND_SMS)) {
            android.util.Log.e(TAG, "SEND_SMS permission is not granted!")
            result.error("PERMISSION_DENIED", "SEND_SMS permission is not granted", null)
            return
        }

        // Log default SMS app status (diagnostic)
        android.util.Log.d(TAG, "isDefaultSmsApp=${isDefaultSmsApp()}")

        // Ensure contact exists (best-effort)
        try {
            ensureContactExists(context, recipient, systemName, customerName)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Contact creation skipped: ${e.message}", e)
        }

        try {
            val smsManager = getSmsManager(simSlot)

            // ── Unique action strings so concurrent sends don't collide ──
            val uid       = UUID.randomUUID().toString()
            val sentAction = "SMS_SENT_$uid"

            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_ONE_SHOT
            }

            val sentIntent = PendingIntent.getBroadcast(
                context, 0, Intent(sentAction), pendingFlags
            )

            val sentReceiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context?, intent: Intent?) {
                    try {
                        context.unregisterReceiver(this)
                    } catch (_: Exception) {}

                    // ── IMPORTANT: Android SMS resultCode values ──
                    // Activity.RESULT_OK     = -1  → SUCCESS
                    // SmsManager.RESULT_ERROR_GENERIC_FAILURE = 1
                    // SmsManager.RESULT_ERROR_RADIO_OFF       = 2
                    // SmsManager.RESULT_ERROR_NULL_PDU        = 3
                    // SmsManager.RESULT_ERROR_NO_SERVICE      = 4
                    android.util.Log.d(TAG, "SMS sent broadcast resultCode=$resultCode")

                    when (resultCode) {
                        Activity.RESULT_OK -> {
                            android.util.Log.d(TAG, "SMS sent successfully to $recipient")
                            // Write to Sent box so it shows in the native SMS app
                            writeSentSmsToProvider(recipient, body)
                            result.success("sent")
                        }
                        SmsManager.RESULT_ERROR_NO_SERVICE -> {
                            android.util.Log.w(TAG, "SMS failed: No service (4)")
                            result.success("failed_no_service")
                        }
                        SmsManager.RESULT_ERROR_RADIO_OFF -> {
                            android.util.Log.w(TAG, "SMS failed: Radio off (2)")
                            result.success("failed_radio_off")
                        }
                        else -> {
                            android.util.Log.w(TAG, "SMS failed: generic resultCode=$resultCode")
                            result.success("failed_generic_$resultCode")
                        }
                    }
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(sentReceiver, IntentFilter(sentAction), Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                context.registerReceiver(sentReceiver, IntentFilter(sentAction))
            }

            // ── Split long messages automatically ──
            val parts = smsManager.divideMessage(body)
            android.util.Log.d(TAG, "Sending SMS in ${parts.size} part(s) to $recipient")

            if (parts.size == 1) {
                smsManager.sendTextMessage(recipient, null, body, sentIntent, null)
            } else {
                // Multi-part: only attach sentIntent to the LAST part so result fires once
                val sentIntents = ArrayList<PendingIntent?>(parts.size).apply {
                    repeat(parts.size - 1) { add(null) }
                    add(sentIntent)
                }
                smsManager.sendMultipartTextMessage(recipient, null, parts, sentIntents, null)
            }

        } catch (e: Exception) {
            android.util.Log.e(TAG, "SMS send exception: ${e.message}", e)
            result.error("SMS_SEND_FAILED", e.message, null)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Write sent SMS into Telephony provider
    // Visible in any SMS app (including the native messaging app).
    // Only possible when this app IS the Default SMS App; otherwise the OS
    // blocks WRITE_SMS access silently (insert returns null URI).
    // ─────────────────────────────────────────────────────────────────────────

    private fun writeSentSmsToProvider(recipient: String, body: String) {
        try {
            val now = System.currentTimeMillis()
            val values = ContentValues().apply {
                put(Telephony.Sms.ADDRESS,   recipient)
                put(Telephony.Sms.BODY,      body)
                put(Telephony.Sms.DATE,      now)
                put(Telephony.Sms.DATE_SENT, now)
                put(Telephony.Sms.READ,      1)
                put(Telephony.Sms.SEEN,      1)
                put(Telephony.Sms.TYPE,      Telephony.Sms.MESSAGE_TYPE_SENT)
            }

            val uri = context.contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)
            if (uri != null) {
                android.util.Log.d(TAG, "Sent SMS written to Telephony provider: $uri")
            } else {
                android.util.Log.w(
                    TAG,
                    "Could not write sent SMS to provider (null URI). " +
                    "App may not be the Default SMS App — set it as default in phone Settings."
                )
            }
        } catch (e: SecurityException) {
            android.util.Log.w(TAG, "WRITE_SMS denied — app is not Default SMS App: ${e.message}")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error writing sent SMS to provider: ${e.message}", e)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Contact management
    // ─────────────────────────────────────────────────────────────────────────

    private fun ensureContactExists(
        context: Context,
        number: String,
        systemName: String?,
        customerName: String?,
    ) {
        if (!hasPermission(android.Manifest.permission.WRITE_CONTACTS) ||
            !hasPermission(android.Manifest.permission.READ_CONTACTS)) {
            android.util.Log.w(TAG, "Contact permissions not granted — skipping contact creation.")
            return
        }

        if (contactExists(context, number)) {
            android.util.Log.d(TAG, "Contact already exists for $number")
            return
        }

        val displayName = formatContactName(number, systemName, customerName)
        android.util.Log.d(TAG, "Creating contact: $displayName for $number")

        // Find a synced account (prefer Google) to make the contact visible in the Contacts app
        var accountName: String? = null
        var accountType: String? = null
        try {
            val am       = android.accounts.AccountManager.get(context)
            val accounts = am.accounts
            if (accounts != null && accounts.isNotEmpty()) {
                val google = accounts.firstOrNull { it.type.equals("com.google", ignoreCase = true) }
                if (google != null) {
                    accountName = google.name
                    accountType = google.type
                } else {
                    accountName = accounts[0].name
                    accountType = accounts[0].type
                }
                android.util.Log.d(TAG, "Linking contact to account: $accountName ($accountType)")
            }
        } catch (e: SecurityException) {
            android.util.Log.w(TAG, "SecurityException reading accounts: ${e.message}")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error resolving accounts: ${e.message}", e)
        }

        val ops = ArrayList<android.content.ContentProviderOperation>()

        ops.add(
            android.content.ContentProviderOperation
                .newInsert(android.provider.ContactsContract.RawContacts.CONTENT_URI)
                .withValue(android.provider.ContactsContract.RawContacts.ACCOUNT_TYPE, accountType)
                .withValue(android.provider.ContactsContract.RawContacts.ACCOUNT_NAME, accountName)
                .build()
        )

        ops.add(
            android.content.ContentProviderOperation
                .newInsert(android.provider.ContactsContract.Data.CONTENT_URI)
                .withValueBackReference(android.provider.ContactsContract.Data.RAW_CONTACT_ID, 0)
                .withValue(
                    android.provider.ContactsContract.Data.MIMETYPE,
                    android.provider.ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE
                )
                .withValue(
                    android.provider.ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME,
                    displayName
                )
                .withValue(
                    android.provider.ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME,
                    displayName
                )
                .build()
        )

        ops.add(
            android.content.ContentProviderOperation
                .newInsert(android.provider.ContactsContract.Data.CONTENT_URI)
                .withValueBackReference(android.provider.ContactsContract.Data.RAW_CONTACT_ID, 0)
                .withValue(
                    android.provider.ContactsContract.Data.MIMETYPE,
                    android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE
                )
                .withValue(
                    android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER,
                    number
                )
                .withValue(
                    android.provider.ContactsContract.CommonDataKinds.Phone.TYPE,
                    android.provider.ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE
                )
                .build()
        )

        context.contentResolver.applyBatch(android.provider.ContactsContract.AUTHORITY, ops)
        android.util.Log.d(TAG, "Contact created successfully: $displayName")
    }

    private fun contactExists(context: Context, number: String): Boolean {
        return try {
            val uri = android.net.Uri.withAppendedPath(
                android.provider.ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                android.net.Uri.encode(number)
            )
            context.contentResolver
                .query(uri, arrayOf(android.provider.ContactsContract.PhoneLookup._ID), null, null, null)
                .use { cursor -> cursor?.moveToFirst() == true }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Error checking contact existence: ${e.message}", e)
            false
        }
    }

    private fun formatContactName(
        phoneNumber: String,
        systemName: String?,
        customerName: String?,
    ): String {
        val digits      = phoneNumber.replace(Regex("\\D"), "")
        val customerNo  = if (digits.length >= 6) digits.takeLast(6) else digits.padEnd(6, '0')
        val sys         = (systemName ?: "System").replace(Regex("\\s+"), "").trim().take(10)
        val cust        = (customerName ?: "Customer").trim()
        val words       = cust.split(Regex("\\s+"))
        val custPart    = if (words.size >= 4) "${words.first()} ${words.last()}" else cust.take(10)
        return "C${customerNo}S${sys}-${custPart}"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private fun hasPermission(permission: String): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.checkSelfPermission(permission) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    companion object {
        private const val TAG = "SmsSenderPlugin"
    }
}
