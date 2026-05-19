<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Replay-attack prevention store.
 *
 * Every nonce from a successfully verified agent report is recorded here.
 * A (agent_id, nonce) pair that already exists causes the request to be
 * rejected with HTTP 409 — enforced structurally by a unique DB constraint,
 * not by application-level convention.
 */
class UsedNonce extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'agent_id',
        'nonce',
        'used_at',
    ];

    protected $casts = [
        'used_at' => 'datetime',
    ];
}
