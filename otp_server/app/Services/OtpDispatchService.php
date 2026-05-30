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
     * When $contactName is provided the SMS body:
     *   1. Personalises the greeting with the recipient's name.
     *   2. Appends a vCard block so the receiving SMS app can offer to save
     *      the registrant's details as a contact automatically.
     *
     * @param  string $contactName  Optional — full name of the registrant.
     * @throws \RuntimeException if no agent with otp_gateway capability is paired.
     */
    public function dispatch(User $user, string $phoneNumber, string $contactName = ''): OtpDispatch
    {
        $agent = Agent::where('capabilities', 'like', '%otp_gateway%')->firstOrFail();

        $plainOtp = $this->generateOtp();
        $expiry   = config('otp_server.otp_expiry_minutes', 5);

        $dispatch = OtpDispatch::create([
            'user_id'      => $user->id,
            'phone_number' => $phoneNumber,
            'otp_hash'     => Hash::make($plainOtp),
            'status'       => 'pending',
            'expires_at'   => now()->addMinutes($expiry),
        ]);

        $messageBody = $this->buildMessageBody(
            otp:         $plainOtp,
            expiry:      $expiry,
            contactName: $contactName,
            phoneNumber: $phoneNumber,
        );

        broadcast(new AgentCommandDispatched(
            systemId:              $agent->system_id,
            capability:            'otp_gateway',
            commandId:             (string) $dispatch->id,
            recipientPhoneNumber:  $phoneNumber,
            messageBody:           $messageBody,
            issuedAt:              now()->toIso8601String(),
            simSlot:               'defaultSlot',
            customerName:          $contactName ?: 'Admin',
            systemName:            'SuperAdmin',
        ));

        $dispatch->update(['status' => 'dispatched']);

        return $dispatch;
    }

    /**
     * Builds the full SMS body.
     *
     * When a contact name is provided the message ends with a vCard block.
     * Many Android SMS applications (Google Messages, Samsung Messages) recognise
     * an inline vCard and show a "Save contact" prompt to the recipient —
     * allowing them to store their registered details in one tap.
     *
     * vCard spec: RFC 6350 / vCard 3.0 (widest device support).
     */
    private function buildMessageBody(
        string $otp,
        int    $expiry,
        string $contactName,
        string $phoneNumber,
    ): string {
        $greeting = $contactName
            ? "Hi {$contactName},"
            : 'Hello,';

        $body = "{$greeting}\n"
            . "Your verification code is: {$otp}\n"
            . "It expires in {$expiry} minutes. Do not share it.";

        if ($contactName !== '') {
            $vcard = $this->buildVCard($contactName, $phoneNumber);
            $body .= "\n\n{$vcard}";
        }

        return $body;
    }

    /**
     * Builds a minimal vCard 3.0 block for the registrant.
     *
     * The TEL field is the recipient's own number so that when they tap
     * "Save contact" in their SMS app their name and number are pre-filled.
     */
    private function buildVCard(string $fullName, string $phoneNumber): string
    {
        // Escape special vCard characters in the name (comma, semicolon, backslash).
        $escaped = str_replace(['\\', ',', ';'], ['\\\\', '\\,', '\\;'], $fullName);

        return implode("\r\n", [
            'BEGIN:VCARD',
            'VERSION:3.0',
            "FN:{$escaped}",
            "N:{$escaped};;;;",
            "TEL;TYPE=CELL:{$phoneNumber}",
            'END:VCARD',
        ]);
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
