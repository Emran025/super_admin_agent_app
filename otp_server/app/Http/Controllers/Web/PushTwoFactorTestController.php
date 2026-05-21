<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\ExternalSystem;
use App\Models\TwoFactorChallenge;
use App\Services\PayloadEncryptionService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\View\View;

/**
 * 2FA Push Testbed — Phase 11 update.
 *
 * Now acts as an external client to exercise the full AES-256-GCM encrypted
 * API gateway flow end-to-end:
 *
 *   1. Validates the dummy credentials (admin / testbed).
 *   2. Locates the default test ExternalSystem (is_test = true, super_admin_login capability).
 *   3. Encrypts the login payload using the system's AES-256 key.
 *   4. POSTs the encrypted envelope to POST /api/v1/external/login.
 *   5. Receives challenge_id, stores it in session, redirects to waiting page.
 *
 * Dummy credentials: username=admin / password=testbed
 */
class PushTwoFactorTestController extends Controller
{
    private const DUMMY_USERNAME = 'admin';
    private const DUMMY_PASSWORD = 'testbed';

    public function __construct(
        private readonly PayloadEncryptionService $encryptionService,
    ) {}

    // -------------------------------------------------------------------------
    // Step 1 — Dummy login form
    // -------------------------------------------------------------------------

    public function showLoginForm(): View
    {
        $agent = \App\Models\Agent::where('capabilities', 'like', '%two_fa%')->first()
            ?? \App\Models\Agent::first();
        $isAgentConnected = $agent ? $agent->isOnline() : false;

        return view('testbed.push.login', compact('isAgentConnected'));
    }

    // -------------------------------------------------------------------------
    // Step 2 — Validate credentials and issue push challenge via encrypted API
    // -------------------------------------------------------------------------

    public function submitLogin(Request $request): RedirectResponse
    {
        $request->validate([
            'username' => 'required|string',
            'password' => 'required|string',
        ]);

        if (
            $request->input('username') !== self::DUMMY_USERNAME ||
            $request->input('password') !== self::DUMMY_PASSWORD
        ) {
            return back()->withErrors([
                'credentials' => 'Invalid credentials. Use username "admin" and password "testbed".',
            ])->withInput(['username' => $request->input('username')]);
        }

        $system = $this->resolveTestSystem('super_admin_login');

        if (!$system) {
            return redirect()->route('testbed.pairing')
                ->withErrors(['system' => 'No test external system with "super_admin_login" capability found. Please create one on the System Pairing page.']);
        }

        $sessionToken = session("ext_system_token_{$system->id}")
            ?? ($system->test_token_encrypted ? \Illuminate\Support\Facades\Crypt::decryptString($system->test_token_encrypted) : null);

        if (!$sessionToken) {
            return redirect()->route('testbed.pairing')
                ->withErrors(['system' => 'Test system token is not in session or database. Please recreate the test system from the pairing page.']);
        }

        $username = $request->input('username');
        $payload  = [
            'username'      => $username,
            'context_label' => 'Login attempt from Testbed browser',
        ];

        $plainKey = $system->getPlaintextEncryptionKey();
        $envelope = $this->encryptionService->encrypt($payload, $plainKey);

        $apiUrl  = url('/api/v1/external/login');
        $apiResp = Http::withToken($sessionToken)
            ->acceptJson()
            ->post($apiUrl, $envelope);

        if ($apiResp->status() !== 202) {
            return back()->withErrors([
                'credentials' => 'API gateway returned: ' . $apiResp->status() . ' — ' . $apiResp->body(),
            ]);
        }

        $challengeId = $apiResp->json('challenge_id');
        $request->session()->put('push_challenge_id', $challengeId);

        return redirect()->route('testbed.push.waiting');
    }

    // -------------------------------------------------------------------------
    // Step 3 — Waiting for agent push approval
    // -------------------------------------------------------------------------

    public function showWaiting(Request $request): View|RedirectResponse
    {
        $challengeId = $request->session()->get('push_challenge_id');

        if (!$challengeId) {
            return redirect()->route('testbed.push.login')
                ->withErrors(['credentials' => 'No active 2FA challenge. Please log in first.']);
        }

        $challenge = TwoFactorChallenge::find($challengeId);

        if (!$challenge) {
            $request->session()->forget('push_challenge_id');
            return redirect()->route('testbed.push.login')
                ->withErrors(['credentials' => 'Challenge not found. Please try again.']);
        }

        if ($challenge->status === 'approved') {
            $request->session()->forget('push_challenge_id');
            return redirect()->route('testbed.hub')
                ->with('success', 'Push 2FA approved! The agent granted access.');
        }

        if ($challenge->status === 'rejected') {
            $request->session()->forget('push_challenge_id');
            return redirect()->route('testbed.push.login')
                ->withErrors(['credentials' => 'Push 2FA rejected by the agent. Access denied.']);
        }

        // Derive the public-facing Reverb connection parameters from the
        // incoming HTTP request so the browser-side WebSocket can reach
        // Reverb through the same public hostname and TLS termination point
        // as the mobile agent, instead of the internal bind address.
        $reverbScheme = $request->secure() ? 'wss' : 'ws';
        $reverbHost   = $request->getHost();
        $reverbPort   = $request->secure() ? 443 : (int) config('otp_server.reverb_port', 8080);

        return view('testbed.push.waiting', [
            'challengeId'  => $challengeId,
            'expiresAt'    => $challenge->expires_at->toIso8601String(),
            'reverbScheme' => $reverbScheme,
            'reverbHost'   => $reverbHost,
            'reverbPort'   => $reverbPort,
            'reverbAppKey' => config('otp_server.reverb_app_key', ''),
        ]);
    }

    // -------------------------------------------------------------------------
    // AJAX poll endpoint — safety-net for race-condition before Reverb connects.
    // -------------------------------------------------------------------------

    public function pollStatus(Request $request): \Illuminate\Http\JsonResponse
    {
        $challengeId = $request->session()->get('push_challenge_id');
        if (!$challengeId) {
            return response()->json(['status' => 'no_session'], 400);
        }

        $challenge = TwoFactorChallenge::find($challengeId);
        if (!$challenge) {
            return response()->json(['status' => 'not_found'], 404);
        }

        return response()->json([
            'status'     => $challenge->status,
            'expired'    => $challenge->isExpired(),
            'expires_at' => $challenge->expires_at->toIso8601String(),
        ]);
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
