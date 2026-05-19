<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\OtpDispatch;
use App\Models\User;
use App\Services\OtpDispatchService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\View\View;

/**
 * SMS Gateway Testbed — simulates a third-party application that requests the
 * paired agent to send a real SMS containing a one-time code.
 *
 * This testbed proves the "SMS Gateway" role of the Super Admin Agent:
 *   Any service that cannot send SMS itself delegates to the agent over Reverb.
 *
 * Step 1  GET  /testbed/sms-gateway          — Enter the recipient phone number.
 * Step 2  POST /testbed/sms-gateway          — Dispatch OTP to agent via Reverb.
 * Step 3  GET  /testbed/sms-gateway/verify   — Enter the 6-digit code received by SMS.
 * Step 4  POST /testbed/sms-gateway/verify   — Verify code; show success or error.
 *
 * No browser session authentication is required — the testbed is publicly
 * accessible and uses a deterministic "testbed" user record for the FK constraint.
 */
class SmsGatewayTestController extends Controller
{
    public function __construct(
        private readonly OtpDispatchService $dispatchService,
    ) {}

    // -------------------------------------------------------------------------
    // Step 1 — Phone number entry form
    // -------------------------------------------------------------------------

    public function showPhoneForm(): View
    {
        return view('testbed.sms.phone');
    }

    // -------------------------------------------------------------------------
    // Step 2 — Dispatch OTP to agent via Reverb
    // -------------------------------------------------------------------------

    public function dispatchOtp(Request $request): RedirectResponse
    {
        $request->validate([
            'full_name'    => ['required', 'string', 'min:2', 'max:80'],
            'phone_number' => ['required', 'string', 'regex:/^\+?[0-9\s\-\(\)]{7,20}$/'],
        ], [
            'full_name.required'   => 'Please enter your full name.',
            'full_name.min'        => 'Name must be at least 2 characters.',
            'phone_number.regex'   => 'Please enter a valid phone number (digits, spaces, +, -, parentheses).',
        ]);

        $user     = $this->getOrCreateTestbedUser();
        $name     = trim($request->input('full_name'));
        $phone    = trim($request->input('phone_number'));
        $dispatch = $this->dispatchService->dispatch($user, $phone, $name);

        $request->session()->put('sms_dispatch_id',   $dispatch->id);
        $request->session()->put('sms_phone_number',  $phone);
        $request->session()->put('sms_contact_name',  $name);

        return redirect()->route('testbed.sms.verify.form');
    }

    // -------------------------------------------------------------------------
    // Step 3 — Code entry form
    // -------------------------------------------------------------------------

    public function showVerifyForm(Request $request): View
    {
        $dispatchId  = $request->session()->get('sms_dispatch_id');
        $phoneNumber = $request->session()->get('sms_phone_number');
        $contactName = $request->session()->get('sms_contact_name', '');

        if (!$dispatchId) {
            return view('testbed.sms.phone')->with('error', 'No active OTP session. Please register first.');
        }

        return view('testbed.sms.verify', compact('phoneNumber', 'contactName'));
    }

    // -------------------------------------------------------------------------
    // Step 4 — Verify the code
    // -------------------------------------------------------------------------

    public function verifyOtp(Request $request): RedirectResponse
    {
        $request->validate([
            'otp' => 'required|string|digits:6',
        ]);

        $dispatchId = $request->session()->pull('sms_dispatch_id');
        $request->session()->forget(['sms_phone_number', 'sms_contact_name']);

        if (!$dispatchId) {
            return redirect()->route('testbed.sms.phone')
                ->withErrors(['otp' => 'No active OTP session. Please start again.']);
        }

        $dispatch = OtpDispatch::find($dispatchId);

        if (!$dispatch || $dispatch->isExpired()) {
            return redirect()->route('testbed.sms.phone')
                ->withErrors(['otp' => 'The OTP has expired. Please request a new one.']);
        }

        if (!Hash::check($request->input('otp'), $dispatch->otp_hash)) {
            // Put the session key back so the user can retry.
            $request->session()->put('sms_dispatch_id', $dispatchId);
            return redirect()->route('testbed.sms.verify.form')
                ->withErrors(['otp' => 'Incorrect code. Please check the SMS and try again.']);
        }

        $dispatch->update(['status' => 'delivered']);

        return redirect()->route('testbed.hub')
            ->with('success', 'SMS Gateway verified! The agent successfully sent the OTP via SMS.');
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /**
     * Returns (or creates) a deterministic testbed user for the OTP FK constraint.
     * This user has no real password and cannot log in — it exists solely so the
     * otp_dispatches.user_id FK can be satisfied in the testbed environment.
     */
    private function getOrCreateTestbedUser(): User
    {
        return User::firstOrCreate(
            ['email' => 'testbed@localhost'],
            [
                'name'     => 'Testbed User',
                'password' => Hash::make(Str::random(32)),
            ]
        );
    }
}
