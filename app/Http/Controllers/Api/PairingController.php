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
 *     "paired_at"          : "<ISO 8601>"
 *   }
 */
class PairingController extends Controller
{
    public function pair(Request $request): JsonResponse
    {
        $data = $request->validate([
            'pairing_token'    => 'required|string',
            'public_key_base64'=> 'required|string',
            'public_key_id'    => 'required|string',
        ]);

        $expectedToken = config('otp_server.pairing_token');
        if (!hash_equals((string) $expectedToken, $data['pairing_token'])) {
            return response()->json(['error' => 'Invalid pairing token.'], 401);
        }

        $fcmToken = $request->header('X-FCM-Token', '');
        if (empty($fcmToken)) {
            return response()->json(['error' => 'X-FCM-Token header is required.'], 422);
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
                'fcm_token'        => $fcmToken,
                'capabilities'     => ['otp_gateway'],
                'paired_at'        => $pairedAt,
            ]
        );

        return response()->json([
            'agent_id'             => $agent->agent_id,
            'system_id'            => $agent->system_id,
            'system_label'         => config('otp_server.system_label', 'OTP Testbed'),
            'base_url'             => config('app.url'),
            'granted_capabilities' => $agent->capabilities,
            'paired_at'            => $agent->paired_at->toIso8601String(),
        ], 201);
    }
}
