<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Represents a single 2FA push-approval challenge.
 *
 * Created when an admin passes username/password authentication and the server
 * needs the paired agent to explicitly approve the login via push notification
 * delivered over Reverb WebSocket.
 *
 * @property string $id                  UUID
 * @property string $agent_id
 * @property string $system_id
 * @property string $challenged_username
 * @property string $status              pending|approved|rejected|expired
 * @property \Carbon\Carbon $expires_at
 */
class TwoFactorChallenge extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'agent_id',
        'system_id',
        'challenged_username',
        'status',
        'expires_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
    ];

    public function isPending(): bool
    {
        return $this->status === 'pending' && $this->expires_at->isFuture();
    }

    public function isExpired(): bool
    {
        return $this->expires_at->isPast();
    }

    public function markApproved(): void
    {
        $this->update(['status' => 'approved']);
    }

    public function markRejected(): void
    {
        $this->update(['status' => 'rejected']);
    }
}
