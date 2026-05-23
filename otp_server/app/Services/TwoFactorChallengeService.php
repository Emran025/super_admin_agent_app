<?php

namespace App\Services;

use App\Events\TwoFactorChallengeIssued;
use App\Models\Agent;
use App\Models\TwoFactorChallenge;
use RuntimeException;

/**
 * Creates a 2FA push challenge and dispatches it to the paired agent via Reverb.
 *
 * Flow:
 *   1. Find the agent with the two_fa capability.
 *   2. Create a TwoFactorChallenge record (status: pending).
 *   3. Broadcast TwoFactorChallengeIssued to private-agent.{systemId}.
 *   4. Return the challenge record so the controller can store its ID in the session.
 *
 * The agent receives the event, shows an "Approve / Reject" prompt, and
 * POSTs its ECDSA-signed decision to POST /api/v1/push-challenges/{id}/respond.
 */
class TwoFactorChallengeService
{
    /**
     * Issue a new push challenge for the given username.
     *
     * @param  string $challengedUsername  The identifier of the user attempting to log in.
     * @param  int    $expirySeconds       How long the agent has to respond.
     *
     * @throws RuntimeException If no agent with two_fa capability is paired.
     */
    public function issue(string $challengedUsername, int $expirySeconds = 120): TwoFactorChallenge
    {
        $agent = Agent::where('capabilities', 'like', '%two_fa%')->first();

        if ($agent === null) {
            throw new RuntimeException(
                'No agent with the two_fa capability is paired. '
                . 'Pair a mobile agent before issuing 2FA challenges.'
            );
        }

        $challenge = TwoFactorChallenge::create([
            'agent_id'            => $agent->agent_id,
            'system_id'           => $agent->system_id,
            'challenged_username' => $challengedUsername,
            'status'              => 'pending',
            'expires_at'          => now()->addSeconds($expirySeconds),
        ]);

        broadcast(new TwoFactorChallengeIssued(
            systemId:           $agent->system_id,
            externalSystemId:   (string) ($challenge->external_system_id ?? $challenge->system_id),
            challengeId:        (string) $challenge->id,
            challengedUsername: $challengedUsername,
            issuedAt:           now()->toIso8601String(),
            expiresAt:          $challenge->expires_at->toIso8601String(),
        ));

        return $challenge;
    }
}
