<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\TwoFactorChallenge;
use App\Services\TwoFactorChallengeService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * 2FA Push Testbed — simulates an admin control panel that requires push
 * approval from the paired Super Admin Agent before granting access.
 *
 * This testbed proves the "Personal Authenticator" role of the agent:
 *   Login credentials are correct, but the final approval comes from the device.
 *
 * Step 1  GET  /testbed/push-2fa             — Dummy login form (username + password).
 * Step 2  POST /testbed/push-2fa             — Validate credentials, issue push challenge.
 * Step 3  GET  /testbed/push-2fa/waiting     — "Waiting for approval" page.
 *                                              Browser subscribes to Reverb via Pusher JS.
 *                                              Redirects automatically when agent responds.
 *
 * The agent receives the TwoFactorChallengeIssued event on its private Reverb channel,
 * shows an "Approve / Reject" prompt, and POSTs a signed decision to:
 *   POST /api/v1/push-challenges/{challengeId}/respond
 *
 * The server broadcasts TwoFactorDecisionMade on the public channel
 * push-2fa-result.{challengeId} which the waiting browser JS listens to.
 *
 * Dummy credentials (hardcoded for the testbed — not a real account):
 *   Username: admin
 *   Password: testbed
 */
class PushTwoFactorTestController extends Controller
{
    // Dummy credentials — the testbed has no real user accounts.
    private const DUMMY_USERNAME = 'admin';
    private const DUMMY_PASSWORD = 'testbed';

    public function __construct(
        private readonly TwoFactorChallengeService $challengeService,
    ) {}

    // -------------------------------------------------------------------------
    // Step 1 — Dummy login form
    // -------------------------------------------------------------------------

    public function showLoginForm(): View
    {
        return view('testbed.push.login');
    }

    // -------------------------------------------------------------------------
    // Step 2 — Validate credentials and issue push challenge
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

        $challenge = $this->challengeService->issue(
            challengedUsername: $request->input('username'),
            expirySeconds:      120,
        );

        $request->session()->put('push_challenge_id', $challenge->id);

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

        // If the challenge is already resolved (agent responded before the page loaded),
        // skip the waiting page and go straight to the result.
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

        return view('testbed.push.waiting', [
            'challengeId'   => $challengeId,
            'expiresAt'     => $challenge->expires_at->toIso8601String(),
            'reverbHost'    => config('otp_server.reverb_host', 'localhost'),
            'reverbPort'    => config('otp_server.reverb_port', 8080),
            'reverbAppKey'  => config('otp_server.reverb_app_key', ''),
        ]);
    }

    // -------------------------------------------------------------------------
    // AJAX poll endpoint — browser polls this to detect decisions made before
    // the Reverb WebSocket is established (race-condition safety net).
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
}
