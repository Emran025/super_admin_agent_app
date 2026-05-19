<?php

namespace App\Http\Controllers\Api;

use App\Events\TwoFactorDecisionMade;
use App\Http\Controllers\Controller;
use App\Models\Agent;
use App\Models\TwoFactorChallenge;
use App\Services\SignatureVerifierService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * POST /api/v1/push-challenges/{challengeId}/respond
 *
 * Called by the mobile agent to submit its approve/reject decision for a
 * 2FA push challenge. The request must be ECDSA-signed identically to
 * POST /api/v1/otp-commands/{id}/report.
 *
 * Signing input (canonical JSON of body + "\n" + nonce + "\n" + decided_at):
 *   canonical({ challenge_id, decision, nonce, decided_at }) + "\n" + nonce + "\n" + decided_at
 *
 * Body:
 *   {
 *     "challenge_id" : "<uuid>",
 *     "decision"     : "approved" | "rejected",
 *     "nonce"        : "<hex32>",
 *     "decided_at"   : "<ISO 8601>"
 *   }
 *
 * Headers:
 *   X-Agent-Public-Key-Id : <publicKeyId>
 *   X-Agent-Nonce         : <hex32>
 *   X-Agent-Timestamp     : <ISO 8601>
 *   X-Agent-Signature     : <base64url DER-encoded ECDSA-SHA256>
 *
 * On success:
 *   - Updates TwoFactorChallenge.status to approved/rejected.
 *   - Broadcasts TwoFactorDecisionMade on public channel push-2fa-result.{challengeId}.
 *   - Returns HTTP 200.
 */
class PushChallengeController extends Controller
{
    public function __construct(
        private readonly SignatureVerifierService $verifier,
    ) {}

    public function respond(Request $request, string $challengeId): JsonResponse
    {
        // --- 1. Agent authentication ---
        $publicKeyId = $request->header('X-Agent-Public-Key-Id');
        if (!$publicKeyId) {
            return response()->json(['error' => 'Missing X-Agent-Public-Key-Id header.'], 401);
        }

        $agent = Agent::where('public_key_id', $publicKeyId)->first();
        if (!$agent) {
            return response()->json(['error' => 'Unknown agent.'], 401);
        }

        // --- 2. Validate body fields ---
        $validated = $request->validate([
            'challenge_id' => 'required|uuid',
            'decision'     => 'required|in:approved,rejected',
            'nonce'        => 'required|string|min:8',
            'decided_at'   => 'required|string',
        ]);

        if ($validated['challenge_id'] !== $challengeId) {
            return response()->json(['error' => 'challenge_id mismatch.'], 422);
        }

        // --- 3. Verify ECDSA signature ---
        $nonce     = $request->header('X-Agent-Nonce', '');
        $timestamp = $request->header('X-Agent-Timestamp', '');
        $signature = $request->header('X-Agent-Signature', '');

        $signingInput = $this->verifier->buildPushChallengeSigningInput(
            challengeId: $challengeId,
            decision:    $validated['decision'],
            nonce:       $validated['nonce'],
            decidedAt:   $validated['decided_at'],
        );

        $isValid = $this->verifier->verify(
            signingInput:       $signingInput,
            base64urlSignature: $signature,
            base64urlPublicKey: $agent->agent_public_key,
        );

        if (!$isValid) {
            return response()->json(['error' => 'Invalid signature.'], 403);
        }

        // --- 4. Load and validate the challenge ---
        $challenge = TwoFactorChallenge::find($challengeId);
        if (!$challenge) {
            return response()->json(['error' => 'Challenge not found.'], 404);
        }

        if ($challenge->agent_id !== $agent->agent_id) {
            return response()->json(['error' => 'This challenge belongs to a different agent.'], 403);
        }

        if (!$challenge->isPending()) {
            return response()->json(['error' => 'Challenge is no longer pending.'], 409);
        }

        // --- 5. Record decision and notify the waiting browser ---
        $decision = $validated['decision'];
        $decidedAt = $validated['decided_at'];

        if ($decision === 'approved') {
            $challenge->markApproved();
        } else {
            $challenge->markRejected();
        }

        broadcast(new TwoFactorDecisionMade(
            challengeId: $challengeId,
            decision:    $decision,
            decidedAt:   $decidedAt,
        ));

        return response()->json(['status' => 'ok', 'decision' => $decision]);
    }
}
