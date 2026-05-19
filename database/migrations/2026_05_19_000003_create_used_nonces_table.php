<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Used nonces table — replay attack prevention (Phase 8 Constraint 2.1, Phase 10 Step 2.3).
 *
 * Every nonce received on a webhook report is stored here after successful verification.
 * Before processing any report, the server checks this table. If the (agent_id, nonce) pair
 * exists, the request is rejected with HTTP 409 Conflict — idempotency enforced structurally.
 *
 * Security invariant: A valid, signed payload replayed with the same nonce MUST be rejected.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('used_nonces', function (Blueprint $table) {
            $table->id();
            $table->string('agent_id');
            $table->string('nonce', 64);
            $table->timestamp('used_at');
            $table->unique(['agent_id', 'nonce']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('used_nonces');
    }
};
