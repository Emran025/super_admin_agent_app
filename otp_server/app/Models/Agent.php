<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

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
        'last_seen_at',
    ];

    protected $casts = [
        'capabilities' => 'array',
        'paired_at'    => 'datetime',
        'last_seen_at' => 'datetime',
    ];

    /**
     * Checks whether this agent is currently online/connected.
     * Checks if last_seen_at is within the last 60 seconds.
     * Also queries Reverb's local API using Pusher SDK if connection parameters are available.
     */
    public function isOnline(): bool
    {
        // 1. Quick fallback check — if they reported anything in the last 60 seconds, they are online.
        if ($this->last_seen_at && $this->last_seen_at->greaterThanOrEqualTo(now()->subSeconds(60))) {
            return true;
        }

        // 2. Query Reverb REST API
        try {
            $config = config('broadcasting.connections.reverb');
            if ($config && isset($config['key'], $config['secret'], $config['app_id'])) {
                // Read local Reverb host/port from configuration
                $host = config('otp_server.reverb_host', '127.0.0.1');
                $port = (int) config('otp_server.reverb_port', 8080);

                $pusher = new \Pusher\Pusher(
                    $config['key'],
                    $config['secret'],
                    $config['app_id'],
                    [
                        'host' => $host,
                        'port' => $port,
                        'scheme' => 'http',
                        'useTLS' => false,
                        'timeout' => 2, // Keep it fast
                    ]
                );

                $info = $pusher->get_channel_info($this->reverbChannel());
                if ($info && !empty($info->occupied)) {
                    return true;
                }
            }
        } catch (\Exception $e) {
            // Ignore Reverb connection issues and rely on last_seen_at
        }

        // 3. Final fallback check with a slightly wider window (e.g., 2 minutes)
        return (bool) ($this->last_seen_at && $this->last_seen_at->greaterThanOrEqualTo(now()->subMinutes(2)));
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

    public function externalSystems(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(ExternalSystem::class, 'agent_id', 'agent_id');
    }
}
