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
            val customerName = call.argument<String>("customer_name")
            val systemName = call.argument<String>("system_name")
            android.util.Log.d("SmsSenderPlugin", "Received sendSms command for recipient: $recipient, customer: $customerName, system: $systemName")

            if (recipient != null && body != null) {
                sendSms(recipient, body, simSlot, customerName, systemName, result)
            } else {
                android.util.Log.e("SmsSenderPlugin", "Recipient or body is null")
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

        val hasPhoneStatePermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        if (simSlot == null || simSlot.isEmpty() || simSlot.equals("defaultSlot", ignoreCase = true)) {
            if (hasPhoneStatePermission) {
                try {
                    val subscriptionManager = context.getSystemService(SubscriptionManager::class.java)
                    if (subscriptionManager != null) {
                        val activeList = subscriptionManager.activeSubscriptionInfoList
                        if (activeList != null && activeList.size == 1) {
                            val subId = activeList[0].subscriptionId
                            android.util.Log.d("SmsSenderPlugin", "Only 1 active SIM found (subId: $subId). Automatically routing default request to it.")
                            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                defaultManager.createForSubscriptionId(subId)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getSmsManagerForSubscriptionId(subId)
                            }
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("SmsSenderPlugin", "Error resolving single active SIM fallback: ${e.message}", e)
                }
            }
            return defaultManager
        }

        val slotIndex = when (simSlot.lowercase()) {
            "sim1" -> 0
            "sim2" -> 1
            else -> return defaultManager
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

    private fun sendSms(
        recipient: String, 
        body: String, 
        simSlot: String?, 
        customerName: String?, 
        systemName: String?, 
        result: Result
    ) {
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

        // Try to automatically create/ensure contact exists so failed/sent SMS shows up nicely
        try {
            ensureContactExists(context, recipient, systemName, customerName)
        } catch (e: Exception) {
            android.util.Log.e("SmsSenderPlugin", "Safe-skip contact creation failure: ${e.message}", e)
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
                    android.util.Log.d("SmsSenderPlugin", "BroadcastReceiver onReceive resultCode: $resultCode")
                    when (resultCode) {
                        Activity.RESULT_OK -> result.success("sent")
                        SmsManager.RESULT_ERROR_NO_SERVICE -> result.success("failed_no_service")
                        else -> result.success("failed_generic_$resultCode")
                    }
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(sentReceiver, IntentFilter(sentAction), Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(sentReceiver, IntentFilter(sentAction))
            }

            android.util.Log.d("SmsSenderPlugin", "Calling smsManager.sendTextMessage")
            smsManager.sendTextMessage(recipient, null, body, sentIntent, null)
        } catch (e: Exception) {
            android.util.Log.e("SmsSenderPlugin", "SMS Send Exception: ", e)
            result.error("SMS_SEND_FAILED", e.message, null)
        }
    }

    private fun ensureContactExists(context: Context, number: String, systemName: String?, customerName: String?) {
        val hasContactsPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.checkSelfPermission(android.Manifest.permission.WRITE_CONTACTS) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    && context.checkSelfPermission(android.Manifest.permission.READ_CONTACTS) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        if (!hasContactsPermission) {
            android.util.Log.w("SmsSenderPlugin", "WRITE_CONTACTS or READ_CONTACTS permission not granted. Skipping contact creation.")
            return
        }

        try {
            if (contactExists(context, number)) {
                android.util.Log.d("SmsSenderPlugin", "Contact already exists for number: $number")
                return
            }

            val displayName = formatContactName(number, systemName, customerName)
            android.util.Log.d("SmsSenderPlugin", "Creating contact: $displayName for number: $number")

            // Retrieve synced account details from the device to make it visible
            var accountName: String? = null
            var accountType: String? = null
            try {
                val accountManager = android.accounts.AccountManager.get(context)
                val accounts = accountManager.accounts
                if (accounts != null && accounts.isNotEmpty()) {
                    val googleAccount = accounts.firstOrNull { it.type.equals("com.google", ignoreCase = true) }
                    if (googleAccount != null) {
                        accountName = googleAccount.name
                        accountType = googleAccount.type
                    } else {
                        accountName = accounts[0].name
                        accountType = accounts[0].type
                    }
                    android.util.Log.d("SmsSenderPlugin", "Found active account to link contact: name=$accountName, type=$accountType")
                }
            } catch (e: SecurityException) {
                android.util.Log.w("SmsSenderPlugin", "SecurityException reading accounts: using local fallback.")
            } catch (e: Exception) {
                android.util.Log.e("SmsSenderPlugin", "Error resolving active accounts: ${e.message}", e)
            }

            val ops = ArrayList<android.content.ContentProviderOperation>()

            ops.add(android.content.ContentProviderOperation.newInsert(android.provider.ContactsContract.RawContacts.CONTENT_URI)
                .withValue(android.provider.ContactsContract.RawContacts.ACCOUNT_TYPE, accountType)
                .withValue(android.provider.ContactsContract.RawContacts.ACCOUNT_NAME, accountName)
                .build())

            ops.add(android.content.ContentProviderOperation.newInsert(android.provider.ContactsContract.Data.CONTENT_URI)
                .withValueBackReference(android.provider.ContactsContract.Data.RAW_CONTACT_ID, 0)
                .withValue(android.provider.ContactsContract.Data.MIMETYPE, android.provider.ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
                .withValue(android.provider.ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME, displayName)
                .withValue(android.provider.ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME, displayName)
                .build())

            ops.add(android.content.ContentProviderOperation.newInsert(android.provider.ContactsContract.Data.CONTENT_URI)
                .withValueBackReference(android.provider.ContactsContract.Data.RAW_CONTACT_ID, 0)
                .withValue(android.provider.ContactsContract.Data.MIMETYPE, android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
                .withValue(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER, number)
                .withValue(android.provider.ContactsContract.CommonDataKinds.Phone.TYPE, android.provider.ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE)
                .build())

            context.contentResolver.applyBatch(android.provider.ContactsContract.AUTHORITY, ops)
            android.util.Log.d("SmsSenderPlugin", "Successfully created contact: $displayName")
        } catch (e: Exception) {
            android.util.Log.e("SmsSenderPlugin", "Failed to create contact for $number: ${e.message}", e)
        }
    }

    private fun contactExists(context: Context, number: String): Boolean {
        try {
            val lookupUri = android.net.Uri.withAppendedPath(
                android.provider.ContactsContract.PhoneLookup.CONTENT_FILTER_URI, 
                android.net.Uri.encode(number)
            )
            val projection = arrayOf(android.provider.ContactsContract.PhoneLookup._ID)
            val cursor = context.contentResolver.query(lookupUri, projection, null, null, null)
            try {
                if (cursor != null && cursor.moveToFirst()) {
                    return true
                }
            } finally {
                cursor?.close()
            }
        } catch (e: Exception) {
            android.util.Log.e("SmsSenderPlugin", "Error checking if contact exists: ${e.message}", e)
        }
        return false
    }

    private fun formatContactName(phoneNumber: String, systemName: String?, customerName: String?): String {
        // 1. Customer Number (take last 6 digits of numeric representation)
        val digits = phoneNumber.replace(Regex("\\D"), "")
        val customerNo = if (digits.length >= 6) {
            digits.substring(digits.length - 6)
        } else {
            digits.padEnd(6, '0')
        }
        
        // 2. System Name (first 10 chars, trimmed, no spaces)
        val sys = (systemName ?: "System").replace(Regex("\\s+"), "").trim()
        val sysPart = if (sys.length > 10) sys.substring(0, 10) else sys
        
        // 3. Customer Name (if 4+ words, first & last word; otherwise first 10 chars)
        val cust = (customerName ?: "Customer").trim()
        val words = cust.split(Regex("\\s+"))
        val custPart = if (words.size >= 4) {
            "${words.first()} ${words.last()}"
        } else {
            if (cust.length > 10) cust.substring(0, 10) else cust
        }
        
        return "C${customerNo}S${sysPart}-${custPart}"
    }
}
