<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\OtpDispatch;
use App\Services\OtpDispatchService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\View\View;

/**
 * Minimal OTP verification UI controller for the testbed.
 *
 * Flow:
 *   POST /otp/send   — Dispatch an OTP to the paired agent via FCM.
 *   GET  /otp/verify — Show the OTP entry form.
 *   POST /otp/verify — Validate the OTP entered by the user.
 *
 * Security invariant: OTP is verified using Hash::check() against the stored bcrypt hash.
 * The plaintext OTP is never stored server-side — it lives only in the FCM message body
 * and in the user's SMS inbox. Expired dispatches are rejected regardless of OTP correctness.
 */
class OtpVerificationController extends Controller
{
    public function __construct(
        private readonly OtpDispatchService $dispatchService,
    ) {}

    /**
     * Display the OTP entry form.
     */
    public function showVerificationForm(Request $request): View
    {
        return view('auth.verify-otp', [
            'dispatchId' => $request->session()->get('otp_dispatch_id'),
        ]);
    }

    /**
     * Dispatch a new OTP to the agent (called after successful password-based login).
     */
    public function sendOtp(Request $request): RedirectResponse
    {
        $request->validate([
            'phone_number' => 'required|string',
        ]);

        $user = Auth::user();
        $dispatch = $this->dispatchService->dispatch($user, $request->input('phone_number'));

        $request->session()->put('otp_dispatch_id', $dispatch->id);

        return redirect()->route('otp.verify.form');
    }

    /**
     * Verify the OTP code entered by the user.
     *
     * Checks (in order):
     *   1. A pending dispatch exists for this session.
     *   2. The dispatch has not expired (expires_at check).
     *   3. Hash::check($inputOtp, $dispatch->otp_hash) returns true.
     *
     * On success, the dispatch status is set to 'delivered' by convention
     * (the real status update comes from the signed agent webhook report).
     */
    public function verifyOtp(Request $request): RedirectResponse
    {
        $request->validate([
            'otp' => 'required|string|digits:6',
        ]);

        $dispatchId = $request->session()->pull('otp_dispatch_id');

        if (!$dispatchId) {
            return redirect()->route('otp.verify.form')->withErrors(['otp' => 'No active OTP session.']);
        }

        $dispatch = OtpDispatch::find($dispatchId);

        if (!$dispatch || $dispatch->isExpired()) {
            return redirect()->route('otp.verify.form')->withErrors(['otp' => 'OTP has expired. Please request a new one.']);
        }

        if (!Hash::check($request->input('otp'), $dispatch->otp_hash)) {
            return redirect()->route('otp.verify.form')->withErrors(['otp' => 'Invalid OTP. Please try again.']);
        }

        $dispatch->update(['status' => 'delivered']);

        return redirect()->intended('/dashboard')->with('success', 'Two-factor authentication successful.');
    }
}
