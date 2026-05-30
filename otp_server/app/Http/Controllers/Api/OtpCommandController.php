<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Agent;
use App\Models\OtpDispatch;
use App\Services\CanonicalJsonService;
use App\Services\SignatureVerifierService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * GET /v1/otp-commands/{commandId}
 *
 * Returns the full OTP dispatch command to the mobile agent.
 * The agent receives a lightweight trigger over the Reverb WebSocket channel
 * ({capability, command_id, system_id}), then calls this endpoint to fetch
 * the full SMS dispatch payload.
 *
 * Authentication: ECDSA-SHA256 P-256 signed request headers (same mechanism
 * as AgentReportController). For a GET request the canonical body is an
 * empty string, so the signing input is: "" + "\n" + nonce + "\n" + timestamp.
 *
 * Response matches OtpDispatchCommandDto on the Flutter side:
 *   {
 *     "command_id"             : "<uuid>",
 *     "system_id"              : "<uuid>",
 *     "recipient_phone_number" : "<E.164 phone number>",
 *     "message_body"           : "<SMS text with OTP>",
 *     "issued_at"              : "<ISO 8601>",
 *     "sim_slot"               : "defaultSlot"
 *   }
 *
 * NOTE: message_body is the full SMS text broadcast via Reverb. The server
 * does NOT re-derive the OTP here — the message body is stored on the dispatch.
 */
class OtpCommandController extends Controller
{
    public function __construct(
        private readonly SignatureVerifierService $verifier,
    ) {}

    public function show(Request $request, string $commandId): JsonResponse
    {
        $publicKeyId = $request->header('X-Agent-Public-Key-Id');
        if (!$publicKeyId) {
            return response()->json(['error' => 'Missing X-Agent-Public-Key-Id header.'], 401);
        }

        $agent = Agent::where('public_key_id', $publicKeyId)->first();
        if (!$agent) {
            return response()->json(['error' => 'Unknown agent.'], 401);
        }

        $nonce     = $request->header('X-Agent-Nonce', '');
        $timestamp = $request->header('X-Agent-Timestamp', '');
        $signature = $request->header('X-Agent-Signature', '');

        // GET request has no body — canonical body is empty string.
        // Signing input: "" + "\n" + nonce + "\n" + timestamp
        $signingInput = '' . "\n" . $nonce . "\n" . $timestamp;

        $isValid = $this->verifier->verify(
            signingInput:       $signingInput,
            base64urlSignature: $signature,
            base64urlPublicKey: $agent->agent_public_key,
        );

        if (!$isValid) {
            return response()->json(['error' => 'Invalid signature.'], 403);
        }

        $dispatch = OtpDispatch::find($commandId);
        if ($dispatch === null) {
            return response()->json(['error' => 'Command not found.'], 404);
        }

        if ($dispatch->isExpired()) {
            return response()->json(['error' => 'Command has expired.'], 410);
        }

        $systemName = $dispatch->externalSystem ? $dispatch->externalSystem->name : 'SuperAdmin';
        $customerName = $dispatch->user ? $dispatch->user->name : 'Customer';

        // message_body is NOT stored server-side (the plaintext OTP was delivered
        // via the Reverb WebSocket event and is never persisted — Axiom 3 / Constraint 2.3).
        // This field returns a safe template so the Flutter DTO can still be parsed.
        return response()->json([
            'command_id'             => $dispatch->id,
            'system_id'              => $agent->system_id,
            'recipient_phone_number' => $dispatch->phone_number,
            'message_body'           => 'Your verification code was delivered via the secure agent channel.',
            'issued_at'              => $dispatch->created_at->toIso8601String(),
            'sim_slot'               => 'defaultSlot',
            'customer_name'          => $customerName,
            'system_name'            => $systemName,
        ]);
    }
}
