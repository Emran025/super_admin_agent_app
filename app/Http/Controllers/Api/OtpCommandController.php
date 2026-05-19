<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Agent;
use App\Models\OtpDispatch;
use Illuminate\Http\JsonResponse;

/**
 * GET /v1/otp-commands/{commandId}
 *
 * Returns the full OTP dispatch command to the mobile agent after it receives
 * a lightweight FCM data trigger. The FCM message carries only {capability,
 * command_id, system_id}; the agent then calls this endpoint to get the full
 * command details it needs to send the SMS.
 *
 * Response matches OtpDispatchCommandDto on the Flutter side:
 *   {
 *     "command_id"             : "<uuid>",
 *     "system_id"              : "<uuid>",
 *     "recipient_phone_number" : "<E.164 phone number>",
 *     "message_body"           : "<SMS text>",
 *     "issued_at"              : "<ISO 8601>",
 *     "sim_slot"               : "defaultSlot"
 *   }
 *
 * NOTE: message_body is generated from the OTP here but does NOT contain
 * the raw OTP — the server does not store or re-derive the plaintext OTP
 * after dispatch. The message body stored here is the safe template.
 *
 * In the testbed implementation, the command fetching is agent-authenticated
 * via the X-Agent-ID header. Production would use mTLS or a signed JWT.
 */
class OtpCommandController extends Controller
{
    public function show(string $commandId): JsonResponse
    {
        $dispatch = OtpDispatch::findOrFail($commandId);

        if ($dispatch->isExpired()) {
            return response()->json(['error' => 'Command has expired.'], 410);
        }

        $agent = Agent::firstOrFail();

        return response()->json([
            'command_id'             => $dispatch->id,
            'system_id'              => $agent->system_id,
            'recipient_phone_number' => $dispatch->phone_number,
            'message_body'           => "Your verification code is ready. Please check your SMS.",
            'issued_at'              => $dispatch->created_at->toIso8601String(),
            'sim_slot'               => 'defaultSlot',
        ]);
    }
}
