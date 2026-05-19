<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Agent;
use App\Models\OtpDispatch;
use App\Models\UsedNonce;
use App\Services\SignatureVerifierService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * POST /v1/otp-commands/{commandId}/report
 *
 * Receives a cryptographically signed delivery report from the mobile agent.
 *
 * Security chain (all gates must pass before the status is updated):
 *  1. Request body validation — all required fields present and typed correctly.
 *  2. Agent lookup — agent_public_key_id must match a known paired agent.
 *  3. Nonce replay check — (agent_id, nonce) must not exist in used_nonces.
 *     Reject with HTTP 409 if the pair already exists.
 *  4. Signature verification — ECDSA-SHA256 P-256 over canonical signing input.
 *     Reject with HTTP 401 if openssl_verify() does not return 1.
 *  5. Command ownership — commandId URL param must match command_id in the body.
 *  6. Nonce consumed — record (agent_id, nonce) in used_nonces atomically before
 *     updating the dispatch status.
 *
 * Expected request body (matches OtpReportRequestDto on the Flutter side):
 *   {
 *     "command_id"         : "<uuid>",
 *     "status"             : "delivered" | "failed",
 *     "reported_at"        : "<ISO 8601>",
 *     "nonce"              : "<hex string — cryptographically random 16 bytes>",
 *     "agent_public_key_id": "<UUID matching Agent.public_key_id>",
 *     "signature"          : "<base64url DER-encoded ECDSA-SHA256 signature>"
 *   }
 *
 * Signing input (must exactly match ExecuteSmsDispatchUseCase on the Flutter side):
 *   CanonicalJson({command_id, nonce, reported_at, status})
 *   + "\n" + nonce + "\n" + reported_at
 *
 * The CanonicalJson step sorts keys alphabetically, uses UTF-8, no whitespace.
 */
class AgentReportController extends Controller
{
    public function __construct(
        private readonly SignatureVerifierService $verifier,
    ) {}

    public function report(Request $request, string $commandId): JsonResponse
    {
        $data = $request->validate([
            'command_id'          => 'required|string',
            'status'              => 'required|in:delivered,failed',
            'reported_at'         => 'required|string',
            'nonce'               => 'required|string|min:8',
            'agent_public_key_id' => 'required|string',
            'signature'           => 'required|string',
        ]);

        // Gate 1 — URL param must match body field
        if ($commandId !== $data['command_id']) {
            return response()->json(['error' => 'Command ID mismatch.'], 422);
        }

        // Gate 2 — Agent lookup
        $agent = Agent::where('public_key_id', $data['agent_public_key_id'])->first();
        if ($agent === null) {
            return response()->json(['error' => 'Unknown agent.'], 404);
        }

        // Gate 3 — Nonce replay prevention (checked before signature to short-circuit cheap)
        $nonceExists = UsedNonce::where('agent_id', $agent->agent_id)
            ->where('nonce', $data['nonce'])
            ->exists();

        if ($nonceExists) {
            return response()->json(['error' => 'Nonce already used — replay detected.'], 409);
        }

        // Gate 4 — Signature verification
        $signingInput = $this->verifier->buildOtpReportSigningInput(
            commandId:  $data['command_id'],
            nonce:      $data['nonce'],
            reportedAt: $data['reported_at'],
            status:     $data['status'],
        );

        if (!$this->verifier->verify($signingInput, $data['signature'], $agent->agent_public_key)) {
            return response()->json(['error' => 'Signature verification failed.'], 401);
        }

        // Gate 5 — Command ownership and existence
        $dispatch = OtpDispatch::find($commandId);
        if ($dispatch === null) {
            return response()->json(['error' => 'Command not found.'], 404);
        }

        // Gate 6 — Consume nonce and update status atomically
        DB::transaction(function () use ($agent, $data, $dispatch) {
            UsedNonce::create([
                'agent_id' => $agent->agent_id,
                'nonce'    => $data['nonce'],
                'used_at'  => now(),
            ]);

            $dispatch->update(['status' => $data['status']]);
        });

        return response()->json(['status' => $data['status']], 200);
    }
}
