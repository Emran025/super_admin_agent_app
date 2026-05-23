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
 * GET  /api/v1/push-challenges/{challengeId}
 * POST /api/v1/push-challenges/{challengeId}/respond
 *
 * GET — Called by the mobile agent after receiving the Reverb `agent.command`
 * event to fetch and verify the full challenge details before displaying the
 * approval UI. Mirrors GET /api/v1/otp-commands/{commandId}.
 *
 * POST — Called by the mobile agent to submit its approve/reject decision.
 * The request must be ECDSA-signed identically to POST /api/v1/otp-commands/{id}/report.
 *
 * GET signing input  (GET request — canonical body is empty string):
 *   "" + "\n" + nonce + "\n" + timestamp
 *
 * POST signing input (canonical JSON of body + "\n" + nonce + "\n" + decided_at):
 *   canonical({ challenge_id, decision, nonce, decided_at }) + "\n" + nonce + "\n" + decided_at
 *
 * POST Body:
 *   {
 *     "challenge_id" : "<uuid>",
 *     "decision"     : "approved" | "rejected",
 *     "nonce"        : "<hex32>",
 *     "decided_at"   : "<ISO 8601>"
 *   }
 *
 * Headers (both GET and POST):
 *   X-Agent-Public-Key-Id : <publicKeyId>
 *   X-Agent-Nonce         : <hex32>
 *   X-Agent-Timestamp     : <ISO 8601>
 *   X-Agent-Signature     : <base64url DER-encoded ECDSA-SHA256>
 *
 * On GET success — returns:
 *   {
 *     "challenge_id"       : "<uuid>",
 *     "system_id"          : "<uuid>",
 *     "challenged_username": "<string>",
 *     "issued_at"          : "<ISO 8601>",
 *     "expires_at"         : "<ISO 8601>",
 *     "status"             : "pending"
 *   }
 *
 * On POST success:
 *   - Updates TwoFactorChallenge.status to approved/rejected.
 *   - Broadcasts TwoFactorDecisionMade on public channel push-2fa-result.{challengeId}.
 *   - Returns HTTP 200.
 */
class PushChallengeController extends Controller
{
    public function __construct(
        private readonly SignatureVerifierService $verifier,
    ) {}

    public function show(Request $request, string $challengeId): JsonResponse
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

        // --- 2. Verify ECDSA signature (GET — empty canonical body) ---
        $nonce     = $request->header('X-Agent-Nonce', '');
        $timestamp = $request->header('X-Agent-Timestamp', '');
        $signature = $request->header('X-Agent-Signature', '');

        $signingInput = '' . "\n" . $nonce . "\n" . $timestamp;

        $isValid = $this->verifier->verify(
            signingInput:       $signingInput,
            base64urlSignature: $signature,
            base64urlPublicKey: $agent->agent_public_key,
        );

        if (!$isValid) {
            return response()->json(['error' => 'Invalid signature.'], 403);
        }

        // --- 3. Load and authorise ---
        $challenge = TwoFactorChallenge::find($challengeId);
        if (!$challenge) {
            return response()->json(['error' => 'Challenge not found.'], 404);
        }

        if ($challenge->agent_id !== $agent->agent_id) {
            return response()->json(['error' => 'This challenge belongs to a different agent.'], 403);
        }

        if ($challenge->isExpired() && $challenge->status === 'pending') {
            $challenge->update(['status' => 'expired']);
            return response()->json(['error' => 'Challenge has expired.'], 410);
        }

        $agent->update(['last_seen_at' => now()]);

        return response()->json([
            'challenge_id'        => (string) $challenge->id,
            'system_id'           => $challenge->system_id,
            'challenged_username' => $challenge->challenged_username,
            'issued_at'           => $challenge->created_at->toIso8601String(),
            'expires_at'          => $challenge->expires_at->toIso8601String(),
            'status'              => $challenge->status,
        ]);
    }

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

        $agent->update(['last_seen_at' => now()]);

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
