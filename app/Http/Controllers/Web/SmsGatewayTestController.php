<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\ExternalSystem;
use App\Models\OtpDispatch;
use App\Services\PayloadEncryptionService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\View\View;

/**
 * SMS Gateway Testbed — Phase 11 update.
 *
 * Now acts as an external client to exercise the full AES-256-GCM encrypted
 * API gateway flow end-to-end:
 *
 *   1. Locates (or prompts to create) the default test ExternalSystem (is_test = true, otp capability).
 *   2. Builds the OTP payload.
 *   3. Encrypts it using PayloadEncryptionService and the system's key.
 *   4. POSTs the encrypted envelope to POST /api/v1/external/otp.
 *   5. Receives the command_id and stores it in session.
 *   6. Verify step continues to work as before (checks OtpDispatch by ID).
 *
 * This proves the complete flow: external client → gateway → agent → SMS.
 */
class SmsGatewayTestController extends Controller
{
    public function __construct(
        private readonly PayloadEncryptionService $encryptionService,
    ) {}

    // -------------------------------------------------------------------------
    // Step 1 — Phone number entry form
    // -------------------------------------------------------------------------

    public function showPhoneForm(): View
    {
        $hasTestSystem = ExternalSystem::where('is_test', true)
            ->whereJsonContains('capabilities', 'otp')
            ->exists();

        $agent = \App\Models\Agent::where('capabilities', 'like', '%otp_gateway%')->first();
        $isAgentConnected = $agent ? $agent->isOnline() : false;

        return view('testbed.sms.phone', compact('hasTestSystem', 'isAgentConnected'));
    }

    // -------------------------------------------------------------------------
    // Step 2 — Dispatch OTP via the encrypted external API gateway
    // -------------------------------------------------------------------------

    public function dispatchOtp(Request $request): RedirectResponse
    {
        $request->validate([
            'full_name'    => ['required', 'string', 'min:2', 'max:80'],
            'phone_number' => ['required', 'string', 'regex:/^\+?[0-9\s\-\(\)]{7,20}$/'],
        ], [
            'full_name.required'   => 'Please enter your full name.',
            'full_name.min'        => 'Name must be at least 2 characters.',
            'phone_number.regex'   => 'Please enter a valid phone number.',
        ]);

        $system = $this->resolveTestSystem('otp');
        if (!$system) {
            return redirect()->route('testbed.pairing')
                ->withErrors(['system' => 'No test external system with "otp" capability found. Please create one on the System Pairing page.']);
        }

        $name  = trim($request->input('full_name'));
        $phone = trim($request->input('phone_number'));
        $otp   = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        $greeting    = "Hi {$name},";
        $messageBody = "{$greeting}\nYour verification code is: {$otp}\nIt expires in 5 minutes. Do not share it.";

        $payload  = ['phone_number' => $phone, 'message_body' => $messageBody];
        $plainKey = $system->getPlaintextEncryptionKey();
        $envelope = $this->encryptionService->encrypt($payload, $plainKey);

        // Retrieve the plaintext token — we re-hash to find it; token is not stored.
        // Testbed uses the stored api_token_hash for the Authorization header by
        // re-deriving it from the system's stored hash directly as the token.
        // Since plaintext tokens are not stored, the testbed retrieves the system
        // by ID and uses the session-stored token from the creation flow.
        // We also fall back to test_token_encrypted if it exists.
        $sessionToken = session("ext_system_token_{$system->id}")
            ?? ($system->test_token_encrypted ? \Illuminate\Support\Facades\Crypt::decryptString($system->test_token_encrypted) : null);

        if (!$sessionToken) {
            return redirect()->route('testbed.pairing')
                ->withErrors(['system' => 'Test system token is not in session or database. Please recreate the test system.']);
        }

        $apiUrl  = route('api.v1.external.otp');
        $apiResp = Http::withToken($sessionToken)
            ->acceptJson()
            ->post($apiUrl, $envelope);

        if ($apiResp->status() !== 202) {
            return redirect()->route('testbed.sms.phone')
                ->withErrors(['dispatch' => 'API gateway returned: ' . $apiResp->status() . ' — ' . $apiResp->body()]);
        }

        $commandId = $apiResp->json('command_id');

        $request->session()->put('sms_dispatch_id',  $commandId);
        $request->session()->put('sms_phone_number', $phone);
        $request->session()->put('sms_contact_name', $name);
        $request->session()->put('sms_plain_otp',    $otp);

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
            return view('testbed.sms.phone', ['hasTestSystem' => true])
                ->with('error', 'No active OTP session. Please register first.');
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
        $plainOtp   = $request->session()->pull('sms_plain_otp');
        $request->session()->forget(['sms_phone_number', 'sms_contact_name']);

        if (!$dispatchId) {
            return redirect()->route('testbed.sms.phone')
                ->withErrors(['otp' => 'No active OTP session. Please start again.']);
        }

        $enteredOtp = $request->input('otp');

        if ($plainOtp && $enteredOtp !== $plainOtp) {
            $request->session()->put('sms_dispatch_id', $dispatchId);
            $request->session()->put('sms_plain_otp', $plainOtp);
            return redirect()->route('testbed.sms.verify.form')
                ->withErrors(['otp' => 'Incorrect code. Please check the SMS and try again.']);
        }

        // Mark the dispatch as delivered.
        $dispatch = OtpDispatch::find($dispatchId);
        if ($dispatch) {
            $dispatch->update(['status' => 'delivered']);
        }

        return redirect()->route('testbed.hub')
            ->with('success', 'SMS Gateway verified! The agent successfully sent the OTP via SMS.');
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    private function resolveTestSystem(string $capability): ?ExternalSystem
    {
        return ExternalSystem::where('is_test', true)
            ->whereJsonContains('capabilities', $capability)
            ->latest()
            ->first();
    }
}
