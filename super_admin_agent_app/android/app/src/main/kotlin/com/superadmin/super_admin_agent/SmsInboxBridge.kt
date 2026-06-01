package com.superadmin.super_admin_agent

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.provider.ContactsContract
import android.provider.Telephony
import android.util.Log

/**
 * Reads SMS conversation threads from the Android Telephony content provider.
 *
 * Used only by the compensating Chats UI (user messaging), not by agent domains.
 */
object SmsInboxBridge {

    private const val TAG = "SmsInboxBridge"
    private const val MAX_CONVERSATIONS = 200

    fun getConversations(context: Context): List<Map<String, Any?>> {
        val resolver = context.contentResolver
        val results = mutableListOf<Map<String, Any?>>()

        val uri = Telephony.Threads.CONTENT_URI.buildUpon()
            .appendQueryParameter("simple", "true")
            .build()

        val projection = arrayOf(
            Telephony.Threads._ID,
            Telephony.Threads.SNIPPET,
            Telephony.Threads.DATE,
            Telephony.Threads.READ,
            Telephony.Threads.MESSAGE_COUNT,
        )

        val sortOrder = "${Telephony.Threads.DATE} DESC"

        try {
            resolver.query(
                uri,
                projection,
                "${Telephony.Threads.MESSAGE_COUNT} > 0",
                null,
                sortOrder,
            )?.use { cursor ->
                var count = 0
                val idIdx = cursor.getColumnIndexOrThrow(Telephony.Threads._ID)
                val snippetIdx = cursor.getColumnIndexOrThrow(Telephony.Threads.SNIPPET)
                val dateIdx = cursor.getColumnIndexOrThrow(Telephony.Threads.DATE)
                val readIdx = cursor.getColumnIndexOrThrow(Telephony.Threads.READ)

                while (cursor.moveToNext() && count < MAX_CONVERSATIONS) {
                    val threadId = cursor.getLong(idIdx)
                    val address = resolveThreadAddress(resolver, threadId) ?: continue
                    val displayName = resolveContactName(context, address) ?: formatAddress(address)

                    results.add(
                        mapOf(
                            "threadId" to threadId,
                            "address" to address,
                            "displayName" to displayName,
                            "snippet" to (cursor.getString(snippetIdx) ?: ""),
                            "timestampMs" to cursor.getLong(dateIdx),
                            "unreadCount" to countUnreadInThread(resolver, threadId),
                            "isRead" to (cursor.getInt(readIdx) != 0),
                        ),
                    )
                    count++
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "READ_SMS permission denied: ${e.message}")
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query conversations: ${e.message}", e)
            throw e
        }

        return results
    }

    private fun resolveThreadAddress(resolver: ContentResolver, threadId: Long): String? {
        resolver.query(
            Uri.parse("content://sms"),
            arrayOf(Telephony.Sms.ADDRESS),
            "${Telephony.Sms.THREAD_ID} = ?",
            arrayOf(threadId.toString()),
            "${Telephony.Sms.DATE} DESC LIMIT 1",
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getString(0)
            }
        }
        return null
    }

    private fun countUnreadInThread(resolver: ContentResolver, threadId: Long): Int {
        resolver.query(
            Uri.parse("content://sms"),
            arrayOf(Telephony.Sms._ID),
            "${Telephony.Sms.THREAD_ID} = ? AND ${Telephony.Sms.READ} = 0 AND ${Telephony.Sms.TYPE} = ?",
            arrayOf(threadId.toString(), Telephony.Sms.MESSAGE_TYPE_INBOX.toString()),
            null,
        )?.use { return it.count }
        return 0
    }

    private fun resolveContactName(context: Context, phoneNumber: String): String? {
        try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(phoneNumber),
            )
            context.contentResolver.query(
                uri,
                arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    return cursor.getString(0)
                }
            }
        } catch (e: Exception) {
            Log.d(TAG, "Contact lookup skipped: ${e.message}")
        }
        return null
    }

    private fun formatAddress(address: String): String = address.trim()

    fun getMessages(context: Context, threadId: Long): List<Map<String, Any?>> {
        val resolver = context.contentResolver
        val results = mutableListOf<Map<String, Any?>>()

        resolver.query(
            Uri.parse("content://sms"),
            arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
                Telephony.Sms.TYPE,
                Telephony.Sms.READ,
                Telephony.Sms.STATUS,
            ),
            "${Telephony.Sms.THREAD_ID} = ?",
            arrayOf(threadId.toString()),
            "${Telephony.Sms.DATE} ASC",
        )?.use { cursor ->
            val idIdx = cursor.getColumnIndexOrThrow(Telephony.Sms._ID)
            val addrIdx = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val bodyIdx = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val dateIdx = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
            val typeIdx = cursor.getColumnIndexOrThrow(Telephony.Sms.TYPE)
            val statusIdx = cursor.getColumnIndexOrThrow(Telephony.Sms.STATUS)

            while (cursor.moveToNext()) {
                val type = cursor.getInt(typeIdx)
                val isOutgoing = type == Telephony.Sms.MESSAGE_TYPE_SENT ||
                    type == Telephony.Sms.MESSAGE_TYPE_OUTBOX
                val status = cursor.getInt(statusIdx)
                results.add(
                    mapOf(
                        "messageId" to cursor.getLong(idIdx),
                        "address" to (cursor.getString(addrIdx) ?: ""),
                        "body" to (cursor.getString(bodyIdx) ?: ""),
                        "timestampMs" to cursor.getLong(dateIdx),
                        "isOutgoing" to isOutgoing,
                        "deliveryStatus" to mapDeliveryStatus(isOutgoing, status),
                    ),
                )
            }
        }
        return results
    }

    fun markThreadAsRead(context: Context, threadId: Long) {
        val values = ContentValues().apply {
            put(Telephony.Sms.READ, 1)
            put(Telephony.Sms.SEEN, 1)
        }
        context.contentResolver.update(
            Uri.parse("content://sms"),
            values,
            "${Telephony.Sms.THREAD_ID} = ? AND ${Telephony.Sms.READ} = 0",
            arrayOf(threadId.toString()),
        )
        val threadValues = ContentValues().apply {
            put(Telephony.Threads.READ, 1)
        }
        context.contentResolver.update(
            Telephony.Threads.CONTENT_URI,
            threadValues,
            "${Telephony.Threads._ID} = ?",
            arrayOf(threadId.toString()),
        )
    }

    private fun mapDeliveryStatus(isOutgoing: Boolean, telephonyStatus: Int): String {
        if (!isOutgoing) return "received"
        return when (telephonyStatus) {
            Telephony.Sms.STATUS_PENDING -> "pending"
            Telephony.Sms.STATUS_FAILED -> "failed"
            Telephony.Sms.STATUS_COMPLETE -> "sent"
            else -> "sent"
        }
    }
}
