<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Crypt;

/**
 * Represents a third-party system registered with the API Gateway.
 *
 * Security invariants:
 * - api_token_hash is a SHA-256 hash of the issued bearer token. Plaintext NEVER stored.
 * - encryption_key is stored via Crypt::encryptString() and decrypted on read (Axiom 5).
 * - capabilities is a JSON array: ['otp', 'payment', 'super_admin_login'].
 * - is_test = true means sandbox environment; logs are flagged; production servers reject these.
 *
 * @property string   $id
 * @property string   $name
 * @property string   $api_token_hash
 * @property string   $encryption_key   (encrypted at rest; use getPlaintextEncryptionKey())
 * @property array    $capabilities
 * @property bool     $is_test
 * @property ?\Carbon\Carbon $last_used_at
 */
class ExternalSystem extends Model
{
    use HasFactory;
    use HasUuids;

    protected $fillable = [
        'name',
        'api_token_hash',
        'encryption_key',
        'test_token_encrypted',
        'capabilities',
        'is_test',
        'agent_id',
        'last_used_at',
    ];

    protected $casts = [
        'capabilities' => 'array',
        'is_test'      => 'boolean',
        'last_used_at' => 'datetime',
    ];

    // -------------------------------------------------------------------------
    // Encryption key helpers (Axiom 5 — never store plaintext key)
    // -------------------------------------------------------------------------

    /**
     * Stores the given plaintext key encrypted via Laravel's Crypt facade.
     * Call this instead of setting encryption_key directly.
     */
    public function setEncryptionKey(string $plaintextKey): void
    {
        $this->encryption_key = Crypt::encryptString($plaintextKey);
    }

    /**
     * Returns the decrypted plaintext encryption key.
     * The ciphertext stored in the DB is always the result of Crypt::encryptString().
     */
    public function getPlaintextEncryptionKey(): string
    {
        return Crypt::decryptString($this->encryption_key);
    }

    // -------------------------------------------------------------------------
    // Capability checks
    // -------------------------------------------------------------------------

    /**
     * Returns true if this system has the given capability string.
     * Capability strings: 'otp', 'payment', 'super_admin_login'.
     */
    public function hasCapability(string $capability): bool
    {
        return in_array($capability, $this->capabilities ?? [], true);
    }

    // -------------------------------------------------------------------------
    // Relationships
    // -------------------------------------------------------------------------

    public function agent(): \Illuminate\Database\Eloquent\Relations\BelongsTo
    {
        return $this->belongsTo(Agent::class, 'agent_id', 'agent_id');
    }

    public function otpDispatches(): HasMany
    {
        return $this->hasMany(OtpDispatch::class);
    }

    public function twoFactorChallenges(): HasMany
    {
        return $this->hasMany(TwoFactorChallenge::class);
    }
}
