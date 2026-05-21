<?php

namespace App\Http\Controllers\Api\External;

use App\Events\TwoFactorChallengeIssued;
use App\Http\Controllers\Controller;
use App\Models\Agent;
use App\Models\ExternalSystem;
use App\Models\TwoFactorChallenge;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

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
            $agent = Agent::where('agent_id', $system->agent_id)->first();
        }

        // If not explicitly linked, fall back to the first agent with the two_fa capability.
        // Never fall back to an arbitrary agent — that would route 2FA challenges to the wrong device.
        if ($agent === null) {
            $agent = Agent::where('capabilities', 'like', '%two_fa%')->first();
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

        broadcast(new TwoFactorChallengeIssued(
            systemId:           $agent->system_id,
            challengeId:        (string) $challenge->id,
            challengedUsername: $username . ($contextLabel ? " ({$contextLabel})" : ''),
            issuedAt:           now()->toIso8601String(),
        ));

        return response()->json(['challenge_id' => (string) $challenge->id], 202);
    }
}
