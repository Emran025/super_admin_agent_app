<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Agents table — stores every mobile agent that has completed the pairing ceremony.
 *
 * Security invariants:
 * - agent_public_key stores the raw base64url-encoded 65-byte uncompressed EC P-256 point (04||X||Y).
 *   It is used to verify ECDSA-SHA256 signatures on every inbound webhook report.
 * - No plaintext OTP or secret is stored here.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('agents', function (Blueprint $table) {
            $table->id();
            $table->string('system_id')->unique();
            $table->string('agent_id')->unique();
            $table->text('agent_public_key');
            $table->string('public_key_id');
            $table->string('fcm_token');
            $table->json('capabilities');
            $table->timestamp('paired_at');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('agents');
    }
};
