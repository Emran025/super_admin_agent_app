<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Two-factor push challenge records.
 *
 * Each row represents one admin login attempt that has passed password-based
 * authentication and is now waiting for push approval from the paired agent.
 *
 * Status transitions:
 *   pending → approved   (agent sent a signed "approved" response)
 *   pending → rejected   (agent sent a signed "rejected" response)
 *   pending → expired    (expires_at has passed; lazy-evaluated on read)
 *
 * The agent signs its decision with its ECDSA private key so the server can
 * verify it via SignatureVerifierService before changing status.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('two_factor_challenges', function (Blueprint $table) {
            $table->uuid('id')->primary();

            // The agent that must approve/reject this challenge.
            $table->string('agent_id');
            $table->string('system_id');

            // The "user" attempting to log in (dummy username in the testbed).
            $table->string('challenged_username');

            $table->enum('status', ['pending', 'approved', 'rejected', 'expired'])
                  ->default('pending');

            // How long the agent has to respond before the challenge is stale.
            $table->timestamp('expires_at');

            $table->timestamps();

            $table->index('agent_id');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('two_factor_challenges');
    }
};
