package com.superadmin.super_admin_agent

import android.app.Activity
import android.os.Bundle
import android.util.Log

/**
 * Required Activity for Default SMS App eligibility on Android 4.4+.
 *
 * Android requires a composing activity that handles [android.content.Intent.ACTION_SENDTO]
 * with sms/smsto/mms/mmsto schemes to be present for the app to be eligible
 * as the Default SMS App.
 *
 * Since this is a pure headless OTP gateway agent, we simply finish immediately
 * without displaying any UI. The user never interacts with this activity —
 * it only exists to satisfy Android's Default SMS App eligibility requirements.
 */
class ComposeSmsActivity : Activity() {

    companion object {
        private const val TAG = "ComposeSmsActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // This agent does not provide SMS composing UI.
        // Immediately finish — this activity only satisfies the eligibility requirement.
        Log.d(TAG, "ComposeSmsActivity onCreate — finishing immediately (headless agent mode).")
        finish()
    }
}
