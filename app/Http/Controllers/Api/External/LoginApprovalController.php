<?php

namespace App\Http\Controllers\Api\External;

use App\Events\TwoFactorChallengeIssued;
use App\Http\Controllers\Controller;
use App\Models\Agent;
use App\Models\ExternalSystem;
use App\Models\TwoFactorChallenge;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * 2FA Login Approval — External API endpoint.
 *
 * POST /api/v1/external/login
 * Middleware: auth.external, capability:super_admin_login
 *
 * The request payload has already been AES-256-GCM decrypted by VerifyExternalSystem
 * before this controller is reached. Controllers always receive plain parameters.
 *
 * Expected decrypted payload:
 *   { "username": "admin", "context_label": "Login attempt from chrome / Linux" }
 *
 * Flow:
 *   1. Extract authenticated ExternalSystem from request context.
 *   2. Find the paired agent with the two_fa capability.
 *   3. Create a TwoFactorChallenge record linked to external_system_id in 'pending' status.
 *   4. Broadcast LoginApprovalCommand (TwoFactorChallengeIssued) via Reverb.
 *   5. Return HTTP 202 Accepted with { "challenge_id": "<uuid>" }.
 */
class LoginApprovalController extends Controller
{
    public function challenge(Request $request): JsonResponse
    {
        $request->validate([
            'username'      => ['required', 'string'],
            'context_label' => ['sometimes', 'string', 'max:255'],
        ]);

        /** @var ExternalSystem $system */
        $system = $request->attributes->get('external_system');

        // Find the agent linked to this external system
        $agent = null;
        if ($system->agent_id) {
            $agent = Agent::where('agent_id', $system->agent_id)
                ->orderBy('last_seen_at', 'desc')
                ->first();
        }

        // If not explicitly linked, fall back to the most-recently-seen agent with the
        // two_fa capability.  Ordering by last_seen_at desc ensures that if there are
        // multiple paired agents (e.g. old test pairings), the one that is actively
        // connected to Reverb right now is selected.
        if ($agent === null) {
            $agent = Agent::where('capabilities', 'like', '%two_fa%')
                ->orderBy('last_seen_at', 'desc')
                ->first();
        }

        if ($agent === null) {
            return response()->json([
                'error' => 'No agent with two_fa capability is paired. '
                         . 'Pair a mobile agent and link it to this system before issuing 2FA challenges.',
            ], 503);
        }

        $username     = $request->input('username');
        $contextLabel = $request->input('context_label', '');

        $challenge = TwoFactorChallenge::create([
            'agent_id'            => $agent->agent_id,
            'system_id'           => $agent->system_id,
            'external_system_id'  => $system->id,
            'challenged_username' => $username,
            'status'              => 'pending',
            'expires_at'          => now()->addSeconds(120),
            'sandbox_log'         => $system->is_test,
        ]);

        $broadcastOk    = false;
        $broadcastError = null;

        try {
            broadcast(new TwoFactorChallengeIssued(
                systemId:           $agent->system_id,
                externalSystemId:   (string) $system->id,
                challengeId:        (string) $challenge->id,
                challengedUsername: $username . ($contextLabel ? " ({$contextLabel})" : ''),
                issuedAt:           now()->toIso8601String(),
                expiresAt:          $challenge->expires_at->toIso8601String(),
            ));
            $broadcastOk = true;
            Log::info('2FA challenge broadcast OK', [
                'challenge_id'     => (string) $challenge->id,
                'agent_system_id'  => $agent->system_id,
                'reverb_channel'   => 'private-agent.' . $agent->system_id,
            ]);
        } catch (\Throwable $e) {
            $broadcastError = $e->getMessage();
            Log::error('2FA challenge broadcast FAILED', [
                'challenge_id'     => (string) $challenge->id,
                'agent_system_id'  => $agent->system_id,
                'reverb_channel'   => 'private-agent.' . $agent->system_id,
                'error'            => $broadcastError,
            ]);
        }

        return response()->json([
            'challenge_id'    => (string) $challenge->id,
            'agent_system_id' => $agent->system_id,
            'broadcast_ok'    => $broadcastOk,
            'broadcast_error' => $broadcastError,
        ], 202);
    }
}
