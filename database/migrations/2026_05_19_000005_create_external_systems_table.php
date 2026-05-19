<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * External Systems table — one record per third-party client registered with this gateway.
 *
 * Security invariants:
 * - api_token_hash is a SHA-256 hash of the issued bearer token. Plaintext token is NEVER stored.
 * - encryption_key is stored encrypted at rest using Laravel's Crypt::encryptString() (Axiom 5).
 * - capabilities is a JSON array controlling which API endpoints the system may call.
 * - is_test = true marks sandbox systems whose logs must be flagged to prevent telemetry contamination.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('external_systems', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('api_token_hash')->unique();
            $table->text('encryption_key');
            $table->json('capabilities');
            $table->boolean('is_test')->default(false);
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();

            $table->index('api_token_hash');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('external_systems');
    }
};
