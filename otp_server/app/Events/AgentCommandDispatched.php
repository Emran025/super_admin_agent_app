<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast a command to the mobile agent over a private Reverb channel.
 *
 * Channel naming: private-agent.{systemId}
 * The agent subscribes to this channel after pairing using its system_id.
 *
 * Payload mirrors the former FCM data payload — the router on the Flutter side
 * is structurally identical; only the transport layer changes.
 */
class AgentCommandDispatched implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public readonly string $systemId,
        public readonly string $capability,
        public readonly string $commandId,
        public readonly string $recipientPhoneNumber,
        public readonly string $messageBody,
        public readonly string $issuedAt,
        public readonly string $simSlot = 'defaultSlot',
        public readonly ?string $customerName = null,
        public readonly ?string $systemName = null,
    ) {}

    /**
     * The private channel this event is broadcast on.
     *
     * Channel name must match what the Flutter agent subscribes to:
     *   private-agent.{systemId}
     */
    public function broadcastOn(): Channel
    {
        return new PrivateChannel('agent.' . $this->systemId);
    }

    /**
     * Override the broadcast event name so the Flutter router can key off it.
     */
    public function broadcastAs(): string
    {
        return 'agent.command';
    }

    /**
     * The data payload sent to the Flutter agent.
     *
     * Field names intentionally mirror the former FCM data payload so the
     * WsMessageRouter can parse them identically to the old FcmMessageRouter.
     */
    public function broadcastWith(): array
    {
        return [
            'capability'             => $this->capability,
            'command_id'             => $this->commandId,
            'system_id'              => $this->systemId,
            'recipient_phone_number' => $this->recipientPhoneNumber,
            'message_body'           => $this->messageBody,
            'issued_at'              => $this->issuedAt,
            'sim_slot'               => $this->simSlot,
            'customer_name'          => $this->customerName,
            'system_name'            => $this->systemName,
        ];
    }
}
