package com.superadmin.super_admin_agent

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log

/**
 * Required Service for Default SMS App eligibility on Android 4.4+.
 *
 * Android requires a service that handles [android.intent.action.RESPOND_VIA_MESSAGE]
 * with sms/smsto/mms/mmsto schemes to be present for the app to be eligible
 * as the Default SMS App (specifically for "Quick Reply" functionality from
 * notification shade or lock screen).
 *
 * Since this is a pure headless OTP gateway agent, this service does nothing
 * and returns null from [onBind]. It only exists to satisfy the eligibility
 * requirement so that Android shows this app in the "Change default SMS app" dialog.
 */
class HeadlessSmsSendService : Service() {

    companion object {
        private const val TAG = "HeadlessSmsSendService"
    }

    override fun onBind(intent: Intent?): IBinder? {
        Log.d(TAG, "HeadlessSmsSendService onBind — returning null (headless agent mode).")
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "HeadlessSmsSendService onStartCommand — stopping (headless agent mode).")
        stopSelf()
        return START_NOT_STICKY
    }
}
