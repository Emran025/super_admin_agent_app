<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcast the agent's push-approval decision to the waiting browser page.
 *
 * The browser subscribes to the public channel push-2fa-result.{challengeId}
 * using the Pusher JS client. No channel authentication is required on the
 * browser side — the public channel is appropriate because:
 *
 *   1. The challengeId is a UUID with 122 bits of entropy (unguessable).
 *   2. No sensitive information appears in this event — only the decision string.
 *   3. The actual security boundary is ECDSA verification of the agent's signed
 *      response at the API endpoint, not the broadcast channel.
 *
 * The JS listener receives { decision: 'approved' | 'rejected' } and immediately
 * redirects or shows an error message in the waiting UI.
 */
class TwoFactorDecisionMade implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public readonly string $challengeId,
        public readonly string $decision,      // 'approved' | 'rejected'
        public readonly string $decidedAt,
    ) {}

    /**
     * Public channel — the browser does not need to authenticate.
     * The challengeId UUID is the only access control for the testbed.
     */
    public function broadcastOn(): Channel
    {
        return new Channel('push-2fa-result.' . $this->challengeId);
    }

    public function broadcastAs(): string
    {
        return 'decision.made';
    }

    public function broadcastWith(): array
    {
        return [
            'challenge_id' => $this->challengeId,
            'decision'     => $this->decision,
            'decided_at'   => $this->decidedAt,
        ];
    }
}
