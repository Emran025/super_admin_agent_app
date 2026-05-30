package com.superadmin.super_admin_agent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Required component for Default SMS App eligibility on Android 4.4+.
 *
 * When this app is set as the Default SMS App, Android delivers incoming
 * MMS (WAP Push) to this receiver. Since this is a pure agent app with no
 * messaging UI, we simply log and acknowledge the broadcast. We do NOT
 * store MMS content since MMS handling requires significant additional work
 * (downloading parts, etc.) that is out of scope for this OTP gateway.
 */
class MmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "MmsReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        // MMS handling is required for eligibility but not used in this agent.
        Log.d(TAG, "MMS WAP Push received — acknowledged (not processed, agent-only mode).")
        // Do nothing: this app is a headless agent, not an MMS viewer.
        // If MMS support is needed in the future, implement here.
    }
}
