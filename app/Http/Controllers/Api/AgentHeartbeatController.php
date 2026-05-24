<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Agent;
use App\Services\CanonicalJsonService;
use App\Services\SignatureVerifierService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * POST /api/v1/agent/heartbeat
 *
 * Lightweight keep-alive endpoint called by the mobile agent every ~30 seconds.
 *
 * Purpose: keep last_seen_at fresh so the server hub can accurately display
 * whether the agent is online, without relying solely on the Reverb REST API
 * (which may not be reachable from the PHP process on all hosting environments).
 *
 * Security: same ECDSA-signed request pattern as all other agent endpoints.
 * Signing input: canonical_json({}) + "\n" + nonce + "\n" + timestamp.
 * No nonce deduplication — heartbeats are idempotent and fire frequently enough
 * that TOCTOU is not a meaningful attack surface here.
 */
class AgentHeartbeatController extends Controller
{
    public function __construct(
        private readonly SignatureVerifierService $verifier,
    ) {}

    public function heartbeat(Request $request): JsonResponse
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

        // Canonical JSON of an empty body is "{}" — matches Flutter's signing interceptor
        // when no request body fields are present.
        $canonicalBody = CanonicalJsonService::encode([]);
        $signingInput  = $canonicalBody . "\n" . $nonce . "\n" . $timestamp;

        if (!$this->verifier->verify($signingInput, $signature, $agent->agent_public_key)) {
            return response()->json(['error' => 'Invalid signature.'], 403);
        }

        $agent->update(['last_seen_at' => now()]);

        return response()->json([
            'status'       => 'ok',
            'seen_at'      => now()->toIso8601String(),
            'capabilities' => $agent->capabilities ?? [],
        ]);
    }
}
