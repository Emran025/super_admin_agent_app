<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * OTP dispatches table — one record per OTP generation request.
 *
 * Security invariants (Constraint 2.3 / Axiom 3):
 * - otp_hash stores a bcrypt hash of the plaintext OTP. The plaintext is NEVER stored.
 * - Status transitions: pending -> dispatched -> delivered | failed
 * - Status only moves to delivered/failed when a verified, signed webhook report is received.
 *   It NEVER changes based on assumptions or server-side timeouts.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('otp_dispatches', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('phone_number');
            $table->string('otp_hash');
            $table->enum('status', ['pending', 'dispatched', 'delivered', 'failed'])->default('pending');
            $table->timestamp('expires_at');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('otp_dispatches');
    }
};
