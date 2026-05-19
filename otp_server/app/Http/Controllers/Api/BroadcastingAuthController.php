<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Agent;
use App\Services\CanonicalJsonService;
use App\Services\SignatureVerifierService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * POST /api/v1/broadcasting/auth
 *
 * Custom Pusher/Reverb channel authentication endpoint for the mobile agent.
 *
 * Standard Laravel broadcasting auth requires a session-authenticated user.
 * The mobile agent has no session — it authenticates via ECDSA-signed request
 * headers (the same mechanism used for all other API calls).
 *
 * Flow:
 *  1. Flutter agent POSTs {socket_id, channel_name} with its signing headers.
 *  2. The signing input is: canonical_json({channel_name, socket_id}) + "\n" + nonce + "\n" + timestamp.
 *  3. We verify the ECDSA signature against the agent's stored public key.
 *  4. We confirm the requested channel matches private-agent.{agent.system_id}.
 *  5. We compute and return the Pusher auth string: HMAC-SHA256(secret, "socketId:channel").
 *
 * The returned auth token is used by the Flutter agent to authenticate the private
 * channel subscription with the Reverb WebSocket server.
 */
class BroadcastingAuthController extends Controller
{
    public function __construct(
        private readonly SignatureVerifierService $verifier,
    ) {}

    public function auth(Request $request): JsonResponse
    {
        $data = $request->validate([
            'socket_id'    => 'required|string',
            'channel_name' => 'required|string',
        ]);

        $publicKeyId = $request->header('X-Agent-Public-Key-Id');
        if (!$publicKeyId) {
            return response()->json(['error' => 'Missing X-Agent-Public-Key-Id header.'], 401);
        }

        $agent = Agent::where('public_key_id', $publicKeyId)->first();
        if (!$agent) {
            return response()->json(['error' => 'Unknown agent.'], 401);
        }

        $expectedChannel = 'private-agent.' . $agent->system_id;
        if ($data['channel_name'] !== $expectedChannel) {
            return response()->json(['error' => 'Channel mismatch.'], 403);
        }

        // Reconstruct the signing input the Flutter signing interceptor produced.
        // Interceptor formula: canonicalBody + "\n" + nonce + "\n" + timestamp
        // Body fields (alphabetically sorted by CanonicalJsonService): channel_name, socket_id.
        $nonce     = $request->header('X-Agent-Nonce', '');
        $timestamp = $request->header('X-Agent-Timestamp', '');
        $signature = $request->header('X-Agent-Signature', '');

        $canonicalBody = CanonicalJsonService::encode([
            'channel_name' => $data['channel_name'],
            'socket_id'    => $data['socket_id'],
        ]);
        $signingInput = $canonicalBody . "\n" . $nonce . "\n" . $timestamp;

        $isValid = $this->verifier->verify(
            signingInput:       $signingInput,
            base64urlSignature: $signature,
            base64urlPublicKey: $agent->agent_public_key,
        );

        if (!$isValid) {
            return response()->json(['error' => 'Invalid signature.'], 403);
        }

        $agent->update(['last_seen_at' => now()]);

        // Compute Pusher private channel auth token.
        // Formula: HMAC-SHA256(appSecret, "{socketId}:{channelName}") prefixed with appKey.
        $secret    = config('reverb.apps.apps.0.secret', env('REVERB_APP_SECRET'));
        $key       = config('reverb.apps.apps.0.key', env('REVERB_APP_KEY'));
        $stringToSign = $data['socket_id'] . ':' . $data['channel_name'];
        $authToken = $key . ':' . hash_hmac('sha256', $stringToSign, $secret);

        return response()->json(['auth' => $authToken]);
    }
}
