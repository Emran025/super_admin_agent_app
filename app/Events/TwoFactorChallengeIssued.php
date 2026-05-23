<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast a 2FA push challenge to the mobile agent over its private Reverb channel.
 *
 * The agent receives this on private-agent.{systemId} with the same event name
 * ('agent.command') as OTP commands — the WsMessageRouter routes on 'capability'.
 *
 * The agent UI should display something like:
 *   "Admin login attempt: {challengedUsername} — Approve or Reject?"
 *
 * The agent then submits its signed decision via:
 *   POST /api/v1/push-challenges/{challengeId}/respond
 *
 * NOTE: $systemId (agent's own UUID from pairing) is used solely to derive the
 * private Reverb channel name.  $externalSystemId is the ExternalSystem.id that
 * appears in the agent's linked-systems list and is included in the payload so
 * the agent can match the challenge to a known system.
 */
class TwoFactorChallengeIssued implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public readonly string $systemId,           // agent's system_id — for channel routing only
        public readonly string $externalSystemId,   // ExternalSystem.id  — included in payload
        public readonly string $challengeId,
        public readonly string $challengedUsername,
        public readonly string $issuedAt,
        public readonly string $expiresAt,
    ) {}

    public function broadcastOn(): Channel
    {
        return new PrivateChannel('agent.' . $this->systemId);
    }

    public function broadcastAs(): string
    {
        return 'agent.command';
    }

    public function broadcastWith(): array
    {
        return [
            'capability'          => 'two_fa',
            'command_id'          => $this->challengeId,
            'system_id'           => $this->systemId,
            'external_system_id'  => $this->externalSystemId,
            'challenged_username' => $this->challengedUsername,
            'issued_at'           => $this->issuedAt,
            'expires_at'          => $this->expiresAt,
        ];
    }
}
