<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Records a single OTP generation and dispatch cycle.
 *
 * Security invariants:
 * - otp_hash is a bcrypt hash (Hash::make). Plaintext OTP is NEVER stored.
 * - status transitions to 'delivered' or 'failed' ONLY when a valid signed webhook report
 *   is received and verified by SignatureVerifierService. Never on a timeout or assumption.
 */
class OtpDispatch extends Model
{
    use HasFactory;
    use HasUuids;

    protected $fillable = [
        'user_id',
        'phone_number',
        'otp_hash',
        'status',
        'expires_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isPending(): bool
    {
        return $this->status === 'pending';
    }

    public function isExpired(): bool
    {
        return $this->expires_at->isPast();
    }
}
