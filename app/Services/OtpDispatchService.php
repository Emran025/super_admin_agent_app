<?php

namespace App\Services;

use App\Events\AgentCommandDispatched;
use App\Models\Agent;
use App\Models\OtpDispatch;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\Hash;

/**
 * Generates an OTP, stores it hashed, and dispatches the command to the mobile
 * agent via the self-hosted Reverb WebSocket broadcaster.
 *
 * Security invariants (unchanged from FCM era):
 * - The 6-digit plaintext OTP is generated, used to construct the event payload,
 *   and then IMMEDIATELY discarded from server memory (Constraint 2.3 / Axiom 3).
 * - Only the bcrypt hash (Hash::make()) is persisted in otp_dispatches.otp_hash.
 * - The broadcast event carries the plaintext OTP in message_body exactly once.
 *   After broadcast() returns, the plaintext is unreachable server-side.
 *
 * Transport change: FCM → Reverb WebSocket (private-agent.{systemId} channel).
 */
class OtpDispatchService
{
    public function __construct() {}

    /**
     * Generates an OTP for $user and dispatches it to the paired agent via Reverb.
     *
     * Step sequence (must not be reordered):
     * 1. Generate 6-digit OTP (plaintext lives only in this method's scope).
     * 2. Hash it and save to otp_dispatches with status 'pending'.
     * 3. Find the paired agent (must have otp_gateway capability).
     * 4. Build broadcast payload — plaintext OTP is placed in message_body here.
     * 5. Broadcast AgentCommandDispatched to private-agent.{systemId}.
     * 6. Update dispatch status to 'dispatched'.
     * 7. Return the OtpDispatch record (otp_hash only — plaintext is gone).
     *
     * @throws \RuntimeException if no agent with otp_gateway capability is paired.
     */
    public function dispatch(User $user, string $phoneNumber): OtpDispatch
    {
        $agent = Agent::where('capabilities', 'like', '%otp_gateway%')->firstOrFail();

        $plainOtp = $this->generateOtp();

        $dispatch = OtpDispatch::create([
            'user_id'      => $user->id,
            'phone_number' => $phoneNumber,
            'otp_hash'     => Hash::make($plainOtp),
            'status'       => 'pending',
            'expires_at'   => now()->addMinutes(config('otp_server.otp_expiry_minutes', 5)),
        ]);

        broadcast(new AgentCommandDispatched(
            systemId:              $agent->system_id,
            capability:            'otp_gateway',
            commandId:             (string) $dispatch->id,
            recipientPhoneNumber:  $phoneNumber,
            messageBody:           "Your verification code is {$plainOtp}. Do not share.",
            issuedAt:              now()->toIso8601String(),
        ));

        $dispatch->update(['status' => 'dispatched']);

        return $dispatch;
    }

    /**
     * Generates a cryptographically random 6-digit OTP.
     * Uses random_int() which is CSPRNG-backed.
     */
    private function generateOtp(): string
    {
        return str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    }
}
