<?php

namespace App\Services;

use App\Models\Agent;
use App\Models\OtpDispatch;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\CloudMessage;

/**
 * Generates an OTP, stores it hashed, and dispatches the command to the mobile agent via FCM.
 *
 * Security invariants:
 * - The 6-digit plaintext OTP is generated, used to construct the FCM payload message body,
 *   and then IMMEDIATELY discarded from server memory (Constraint 2.3 / Axiom 3).
 * - Only the bcrypt hash (Hash::make()) is persisted in otp_dispatches.otp_hash.
 * - The FCM data message carries the plaintext OTP in message_body exactly once.
 *   After the FCM call returns, the plaintext is unreachable.
 * - The agent fetches the full OtpDispatchCommand via GET /v1/otp-commands/{commandId}
 *   after receiving the FCM trigger. The FCM data payload contains only the routing keys:
 *   capability, command_id, system_id (and the full command fields for the agent's DTO).
 */
class OtpDispatchService
{
    public function __construct(
        private readonly Messaging $messaging,
    ) {}

    /**
     * Generates an OTP for $user and dispatches it to the paired agent via FCM.
     *
     * Step sequence (must not be reordered):
     * 1. Generate 6-digit OTP (plaintext lives only in this method's scope).
     * 2. Hash it and save to otp_dispatches with status 'pending'.
     * 3. Find the paired agent (must have otp_gateway capability).
     * 4. Build FCM data payload — plaintext OTP is placed in message_body here.
     * 5. Send FCM data message to agent's FCM token.
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
            'expires_at'   => now()->addMinutes(5),
        ]);

        $message = CloudMessage::withTarget('token', $agent->fcm_token)
            ->withData([
                'capability'             => 'otp_gateway',
                'command_id'             => $dispatch->id,
                'system_id'              => $agent->system_id,
                'recipient_phone_number' => $phoneNumber,
                'message_body'           => "Your verification code is {$plainOtp}. Do not share.",
                'issued_at'              => now()->toIso8601String(),
                'sim_slot'               => 'defaultSlot',
            ]);

        $this->messaging->send($message);

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
