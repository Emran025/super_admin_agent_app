package com.superadmin.super_admin_agent

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsManager
import android.util.Log
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * User-initiated SMS send/read (compensating Chats UI).
 * Separate from OTP [SmsSenderPlugin] — no contact auto-creation for gateway.
 */
object UserSmsMessenger {

    private const val TAG = "UserSmsMessenger"

    fun sendMessage(context: Context, address: String, body: String): Map<String, Any?> {
        if (address.isBlank() || body.isBlank()) {
            throw IllegalArgumentException("Address and body are required")
        }
        if (context.checkSelfPermission(android.Manifest.permission.SEND_SMS)
            != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("SEND_SMS permission not granted")
        }

        val messageId = insertOutgoingMessage(context, address, body, Telephony.Sms.STATUS_PENDING)

        try {
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            val uid = UUID.randomUUID().toString()
            val sentAction = "USER_SMS_SENT_$uid"
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_ONE_SHOT
            }
            val sentIntent = PendingIntent.getBroadcast(context, 0, Intent(sentAction), flags)

            val sendResult = AtomicReference("pending")
            val latch = CountDownLatch(1)
            val sentReceiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context?, intent: Intent?) {
                    try {
                        context.applicationContext.unregisterReceiver(this)
                    } catch (_: Exception) {}

                    when (resultCode) {
                        Activity.RESULT_OK -> {
                            updateMessageStatus(context, messageId, Telephony.Sms.STATUS_COMPLETE)
                            sendResult.set("sent")
                            Log.d(TAG, "User SMS sent to $address")
                        }
                        SmsManager.RESULT_ERROR_NO_SERVICE -> {
                            updateMessageStatus(context, messageId, Telephony.Sms.STATUS_FAILED)
                            sendResult.set("failed_no_service")
                        }
                        else -> {
                            updateMessageStatus(context, messageId, Telephony.Sms.STATUS_FAILED)
                            sendResult.set("failed")
                        }
                    }
                    latch.countDown()
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.applicationContext.registerReceiver(
                    sentReceiver,
                    IntentFilter(sentAction),
                    Context.RECEIVER_NOT_EXPORTED,
                )
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                context.applicationContext.registerReceiver(sentReceiver, IntentFilter(sentAction))
            }

            val parts = smsManager.divideMessage(body)
            if (parts.size == 1) {
                smsManager.sendTextMessage(address, null, body, sentIntent, null)
            } else {
                val sentIntents = ArrayList<PendingIntent?>(parts.size).apply {
                    repeat(parts.size - 1) { add(null) }
                    add(sentIntent)
                }
                smsManager.sendMultipartTextMessage(address, null, parts, sentIntents, null)
            }

            latch.await(90, TimeUnit.SECONDS)
            return mapOf(
                "messageId" to messageId,
                "status" to sendResult.get(),
            )
        } catch (e: Exception) {
            updateMessageStatus(context, messageId, Telephony.Sms.STATUS_FAILED)
            Log.e(TAG, "sendMessage failed: ${e.message}", e)
            return mapOf(
                "messageId" to messageId,
                "status" to "failed",
                "error" to (e.message ?: "unknown"),
            )
        }
    }

    fun retryMessage(context: Context, messageId: Long): Map<String, Any?> {
        val msg = getMessageById(context, messageId)
            ?: throw IllegalArgumentException("Message not found")
        val address = msg["address"] as? String ?: throw IllegalArgumentException("No address")
        val body = msg["body"] as? String ?: throw IllegalArgumentException("No body")
        deleteMessage(context, messageId)
        return sendMessage(context, address, body)
    }

    fun deleteMessage(context: Context, messageId: Long): Boolean {
        val deleted = context.contentResolver.delete(
            Uri.parse("content://sms/$messageId"),
            null,
            null,
        )
        return deleted > 0
    }

    private fun getMessageById(context: Context, messageId: Long): Map<String, Any?>? {
        context.contentResolver.query(
            Uri.parse("content://sms"),
            arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY),
            "${Telephony.Sms._ID} = ?",
            arrayOf(messageId.toString()),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return mapOf(
                    "address" to cursor.getString(0),
                    "body" to cursor.getString(1),
                )
            }
        }
        return null
    }

    private fun insertOutgoingMessage(
        context: Context,
        address: String,
        body: String,
        status: Int,
    ): Long {
        val now = System.currentTimeMillis()
        val values = ContentValues().apply {
            put(Telephony.Sms.ADDRESS, address)
            put(Telephony.Sms.BODY, body)
            put(Telephony.Sms.DATE, now)
            put(Telephony.Sms.DATE_SENT, now)
            put(Telephony.Sms.READ, 1)
            put(Telephony.Sms.SEEN, 1)
            put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
            put(Telephony.Sms.STATUS, status)
        }
        val uri = context.contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)
            ?: throw IllegalStateException("Could not insert SMS — is this app the default SMS handler?")
        return uri.lastPathSegment?.toLongOrNull()
            ?: throw IllegalStateException("Invalid message URI: $uri")
    }

    private fun updateMessageStatus(context: Context, messageId: Long, status: Int) {
        val values = ContentValues().apply {
            put(Telephony.Sms.STATUS, status)
        }
        context.contentResolver.update(
            Uri.parse("content://sms/$messageId"),
            values,
            null,
            null,
        )
    }
}
