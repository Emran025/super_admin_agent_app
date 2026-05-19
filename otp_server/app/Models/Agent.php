<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Represents a mobile agent that has completed the pairing ceremony.
 *
 * The agent_public_key is a base64url-encoded 65-byte uncompressed EC P-256 point (04||X||Y).
 * It is the cryptographic anchor — every inbound webhook is verified against it.
 *
 * Command delivery is via Reverb WebSocket on channel private-agent.{system_id}.
 * The channel name is derived at runtime — no FCM token is stored.
 */
class Agent extends Model
{
    use HasFactory;

    protected $fillable = [
        'system_id',
        'agent_id',
        'agent_public_key',
        'public_key_id',
        'capabilities',
        'paired_at',
    ];

    protected $casts = [
        'capabilities' => 'array',
        'paired_at'    => 'datetime',
    ];

    public function otpDispatches(): HasMany
    {
        return $this->hasMany(OtpDispatch::class, 'user_id');
    }

    /**
     * The private Reverb channel this agent listens on.
     * Derived from system_id — no storage required.
     */
    public function reverbChannel(): string
    {
        return 'private-agent.' . $this->system_id;
    }

    /**
     * Checks whether this agent has been granted a specific capability string.
     * Capability strings match the mobile agent's Capability constants: two_fa, otp_gateway, payment_observation.
     */
    public function hasCapability(string $capability): bool
    {
        return in_array($capability, $this->capabilities ?? [], true);
    }
}
