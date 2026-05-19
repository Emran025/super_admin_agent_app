<?php

namespace App\Http\Controllers\Api\External;

use App\Events\AgentCommandDispatched;
use App\Http\Controllers\Controller;
use App\Models\Agent;
use App\Models\ExternalSystem;
use App\Models\OtpDispatch;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

/**
 * OTP Gateway — External API endpoint.
 *
 * POST /api/v1/external/otp
 * Middleware: auth.external, capability:otp
 *
 * The request payload has already been AES-256-GCM decrypted by VerifyExternalSystem
 * before this controller is reached. Controllers always receive plain parameters.
 *
 * Expected decrypted payload:
 *   { "phone_number": "+1234567890", "message_body": "Your code is 654321" }
 *
 * Flow:
 *   1. Extract authenticated ExternalSystem from request context.
 *   2. Find the paired agent with the otp_gateway capability.
 *   3. Store the dispatch record linked to external_system_id.
 *   4. Broadcast OtpDispatchCommand via Reverb to the agent's private channel.
 *   5. Return HTTP 202 Accepted with { "command_id": "<uuid>" }.
 */
class OtpGatewayController extends Controller
{
    public function dispatch(Request $request): JsonResponse
    {
        $request->validate([
            'phone_number' => ['required', 'string'],
            'message_body' => ['required', 'string'],
        ]);

        /** @var ExternalSystem $system */
        $system = $request->attributes->get('external_system');

        // Find the paired agent capable of sending SMS.
        $agent = Agent::where('capabilities', 'like', '%otp_gateway%')->firstOrFail();

        $messageBody = $request->input('message_body');
        $phoneNumber = $request->input('phone_number');

        // Hash the message body (plaintext OTP is provided by the external system — we hash for integrity).
        $dispatch = OtpDispatch::create([
            'user_id'            => null,
            'external_system_id' => $system->id,
            'phone_number'       => $phoneNumber,
            'otp_hash'           => Hash::make($messageBody),
            'status'             => 'pending',
            'expires_at'         => now()->addMinutes((int) config('otp_server.otp_expiry_minutes', 5)),
            'sandbox_log'        => $system->is_test,
        ]);

        broadcast(new AgentCommandDispatched(
            systemId:             $agent->system_id,
            capability:           'otp_gateway',
            commandId:            (string) $dispatch->id,
            recipientPhoneNumber: $phoneNumber,
            messageBody:          $messageBody,
            issuedAt:             now()->toIso8601String(),
        ));

        $dispatch->update(['status' => 'dispatched']);

        return response()->json(['command_id' => (string) $dispatch->id], 202);
    }
}
