package com.superadmin.super_admin_agent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log

/**
 * Required component for Default SMS App eligibility on Android 4.4+.
 *
 * When this app is set as the Default SMS App, Android delivers incoming
 * SMS exclusively via [Telephony.Sms.Intents.SMS_DELIVER_ACTION] to this
 * receiver instead of the shared [Telephony.Sms.Intents.SMS_RECEIVED_ACTION].
 *
 * Responsibility: Store the incoming SMS in the Telephony content provider
 * so it is visible in any SMS viewing app. We do NOT display UI — this is a
 * pure agent app. The SMS is just persisted and logged.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SmsReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_DELIVER_ACTION) {
            Log.w(TAG, "Unexpected action: ${intent.action}")
            return
        }

        try {
            val messages: Array<SmsMessage> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                Telephony.Sms.Intents.getMessagesFromIntent(intent)
            } else {
                @Suppress("DEPRECATION")
                val pdus = intent.extras?.get("pdus") as? Array<*> ?: return
                pdus.mapNotNull { pdu ->
                    @Suppress("DEPRECATION")
                    SmsMessage.createFromPdu(pdu as ByteArray)
                }.toTypedArray()
            }

            if (messages.isEmpty()) {
                Log.w(TAG, "SMS_DELIVER received but no messages found in intent.")
                return
            }

            // Combine multi-part messages
            val sender = messages[0].originatingAddress ?: "Unknown"
            val body = messages.joinToString("") { it.messageBody ?: "" }
            val timestamp = messages[0].timestampMillis

            Log.d(TAG, "Incoming SMS from: $sender, length: ${body.length}")

            // Store in Telephony inbox so it's visible in the native SMS app
            storeSmsInInbox(context, sender, body, timestamp)

        } catch (e: Exception) {
            Log.e(TAG, "Error processing incoming SMS: ${e.message}", e)
        }
    }

    private fun storeSmsInInbox(
        context: Context,
        sender: String,
        body: String,
        timestamp: Long,
    ) {
        try {
            val values = android.content.ContentValues().apply {
                put(Telephony.Sms.ADDRESS, sender)
                put(Telephony.Sms.BODY, body)
                put(Telephony.Sms.DATE, System.currentTimeMillis())
                put(Telephony.Sms.DATE_SENT, timestamp)
                put(Telephony.Sms.READ, 0)   // unread
                put(Telephony.Sms.SEEN, 0)   // unseen
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_INBOX)
            }

            val uri = context.contentResolver.insert(Telephony.Sms.Inbox.CONTENT_URI, values)
            if (uri != null) {
                Log.d(TAG, "SMS stored in inbox: $uri")
            } else {
                Log.e(TAG, "Failed to insert SMS into inbox (null URI returned)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception storing SMS in inbox: ${e.message}", e)
        }
    }
}
