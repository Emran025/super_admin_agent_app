<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Agent;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

/**
 * POST /v1/pair
 *
 * Completes the pairing ceremony between the server and a mobile agent.
 *
 * The agent receives its system_id and Reverb connection parameters in the
 * response. After pairing, the agent connects to the Reverb WebSocket server
 * and subscribes to its private channel: private-agent.{system_id}.
 *
 * Expected request body (matches PairingRequestDto on the Flutter side):
 *   {
 *     "pairing_token"   : "<shared secret distributed out-of-band>",
 *     "public_key_base64": "<base64url 65-byte uncompressed P-256 EC point>",
 *     "public_key_id"   : "<UUID string identifying this keypair>"
 *   }
 *
 * Success response (matches PairingResponseDto on the Flutter side):
 *   {
 *     "agent_id"           : "<uuid>",
 *     "system_id"          : "<uuid>",
 *     "system_label"       : "<human-readable label>",
 *     "base_url"           : "<server base URL>",
 *     "granted_capabilities": ["otp_gateway"],
 *     "paired_at"          : "<ISO 8601>",
 *     "reverb_host"        : "<reverb host>",
 *     "reverb_port"        : <reverb port>,
 *     "reverb_app_key"     : "<reverb app key>"
 *   }
 */
class PairingController extends Controller
{
    public function __construct(
        private readonly \App\Services\SignatureVerifierService $verifier,
    ) {}

    public function pair(Request $request): JsonResponse
    {
        $data = $request->validate([
            'pairing_token'     => 'required|string',
            'public_key_base64' => 'required|string',
            'public_key_id'     => 'required|string',
        ]);

        $expectedToken = config('otp_server.pairing_token');
        if (!hash_equals((string) $expectedToken, $data['pairing_token'])) {
            return response()->json(['error' => 'Invalid pairing token.'], 401);
        }

        $systemId = (string) Str::uuid();
        $agentId  = (string) Str::uuid();
        $pairedAt = now();

        $agent = Agent::updateOrCreate(
            ['public_key_id' => $data['public_key_id']],
            [
                'system_id'        => $systemId,
                'agent_id'         => $agentId,
                'agent_public_key' => $data['public_key_base64'],
                'public_key_id'    => $data['public_key_id'],
                'capabilities'     => ['otp_gateway', 'two_fa', 'payment_observation'],
                'paired_at'        => $pairedAt,
                'last_seen_at'     => $pairedAt,
            ]
        );

        $reverbHost = config('otp_server.reverb_host');
        if (empty($reverbHost) || $reverbHost === 'localhost' || $reverbHost === '127.0.0.1') {
            $reverbHost = $request->getHost();
        }

        $reverbPort = (int) config('otp_server.reverb_port', 8080);
        $reverbScheme = config('otp_server.reverb_scheme', env('REVERB_SCHEME', 'http'));
        if ($request->secure() || $reverbScheme === 'https') {
            if (empty(env('REVERB_PORT')) || $reverbPort === 8080) {
                $reverbPort = 443;
            }
        }

        return response()->json([
            'agent_id'             => $agent->agent_id,
            'system_id'            => $agent->system_id,
            'system_label'         => config('otp_server.system_label', 'OTP Testbed'),
            'base_url'             => config('app.url'),
            'granted_capabilities' => $agent->capabilities,
            'paired_at'            => $agent->paired_at->toIso8601String(),
            'reverb_host'          => $reverbHost,
            'reverb_port'          => $reverbPort,
            'reverb_app_key'       => config('otp_server.reverb_app_key', 'super-admin-reverb-key'),
        ], 201);
    }

    public function linkSystem(Request $request): JsonResponse
    {
        $publicKeyId = $request->header('X-Agent-Public-Key-Id');
        if (!$publicKeyId) {
            return response()->json(['error' => 'Missing X-Agent-Public-Key-Id header.'], 401);
        }

        $agent = Agent::where('public_key_id', $publicKeyId)->first();
        if (!$agent) {
            return response()->json(['error' => 'Unknown agent.'], 401);
        }

        // Verify signature
        $nonce     = $request->header('X-Agent-Nonce', '');
        $timestamp = $request->header('X-Agent-Timestamp', '');
        $signature = $request->header('X-Agent-Signature', '');

        $systemId = $request->input('system_id');
        if (!$systemId) {
            return response()->json(['error' => 'Missing system_id.'], 422);
        }

        // Reconstruct signing input
        $canonicalBody = \App\Services\CanonicalJsonService::encode([
            'system_id' => $systemId,
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

        // Replay protection
        $nonceExists = \App\Models\UsedNonce::where('agent_id', $agent->agent_id)
            ->where('nonce', $nonce)
            ->exists();
        if ($nonceExists) {
            return response()->json(['error' => 'Nonce already used.'], 409);
        }

        \App\Models\UsedNonce::create([
            'agent_id' => $agent->agent_id,
            'nonce'    => $nonce,
            'used_at'  => now(),
        ]);

        $system = \App\Models\ExternalSystem::findOrFail($systemId);
        $system->update(['agent_id' => $agent->agent_id]);

        return response()->json([
            'success' => true,
            'system'  => [
                'id'           => $system->id,
                'name'         => $system->name,
                'capabilities' => $system->capabilities,
                'is_test'      => $system->is_test,
            ]
        ]);
    }

    public function unlinkSystem(Request $request): JsonResponse
    {
        $publicKeyId = $request->header('X-Agent-Public-Key-Id');
        if (!$publicKeyId) {
            return response()->json(['error' => 'Missing X-Agent-Public-Key-Id header.'], 401);
        }

        $agent = Agent::where('public_key_id', $publicKeyId)->first();
        if (!$agent) {
            return response()->json(['error' => 'Unknown agent.'], 401);
        }

        // Verify signature
        $nonce     = $request->header('X-Agent-Nonce', '');
        $timestamp = $request->header('X-Agent-Timestamp', '');
        $signature = $request->header('X-Agent-Signature', '');

        $systemId = $request->input('system_id');
        if (!$systemId) {
            return response()->json(['error' => 'Missing system_id.'], 422);
        }

        // Reconstruct signing input
        $canonicalBody = \App\Services\CanonicalJsonService::encode([
            'system_id' => $systemId,
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

        // Replay protection
        $nonceExists = \App\Models\UsedNonce::where('agent_id', $agent->agent_id)
            ->where('nonce', $nonce)
            ->exists();
        if ($nonceExists) {
            return response()->json(['error' => 'Nonce already used.'], 409);
        }

        \App\Models\UsedNonce::create([
            'agent_id' => $agent->agent_id,
            'nonce'    => $nonce,
            'used_at'  => now(),
        ]);

        $system = \App\Models\ExternalSystem::findOrFail($systemId);
        if ($system->agent_id === $agent->agent_id) {
            $system->update(['agent_id' => null]);
        }

        return response()->json(['success' => true]);
    }

    public function linkedSystems(Request $request): JsonResponse
    {
        $publicKeyId = $request->header('X-Agent-Public-Key-Id');
        if (!$publicKeyId) {
            return response()->json(['error' => 'Missing X-Agent-Public-Key-Id header.'], 401);
        }

        $agent = Agent::where('public_key_id', $publicKeyId)->first();
        if (!$agent) {
            return response()->json(['error' => 'Unknown agent.'], 401);
        }

        // Verify signature
        $nonce     = $request->header('X-Agent-Nonce', '');
        $timestamp = $request->header('X-Agent-Timestamp', '');
        $signature = $request->header('X-Agent-Signature', '');

        // GET request -> canonical body is empty string
        $signingInput = "" . "\n" . $nonce . "\n" . $timestamp;

        $isValid = $this->verifier->verify(
            signingInput:       $signingInput,
            base64urlSignature: $signature,
            base64urlPublicKey: $agent->agent_public_key,
        );

        if (!$isValid) {
            return response()->json(['error' => 'Invalid signature.'], 403);
        }

        // Replay protection
        $nonceExists = \App\Models\UsedNonce::where('agent_id', $agent->agent_id)
            ->where('nonce', $nonce)
            ->exists();
        if ($nonceExists) {
            return response()->json(['error' => 'Nonce already used.'], 409);
        }

        \App\Models\UsedNonce::create([
            'agent_id' => $agent->agent_id,
            'nonce'    => $nonce,
            'used_at'  => now(),
        ]);

        $systems = $agent->externalSystems()->get()->map(function ($sys) {
            return [
                'id'           => $sys->id,
                'name'         => $sys->name,
                'capabilities' => $sys->capabilities,
                'is_test'      => $sys->is_test,
            ];
        });

        return response()->json(['systems' => $systems]);
    }
}
