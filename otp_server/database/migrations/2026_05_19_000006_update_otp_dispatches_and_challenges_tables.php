<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Alter otp_dispatches and two_factor_challenges to support external system linking.
 *
 * Changes:
 * - otp_dispatches.user_id becomes nullable (external API calls have no Laravel user)
 * - otp_dispatches.external_system_id nullable FK → external_systems
 * - otp_dispatches.sandbox_log boolean (true when the originating system is_test = true)
 * - two_factor_challenges.external_system_id nullable FK → external_systems
 * - two_factor_challenges.sandbox_log boolean
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('otp_dispatches', function (Blueprint $table) {
            $table->foreignUuid('external_system_id')
                  ->nullable()
                  ->after('user_id')
                  ->constrained('external_systems')
                  ->nullOnDelete();

            $table->boolean('sandbox_log')->default(false)->after('expires_at');

            // Make user_id nullable so external API calls (no Laravel user) are valid.
            $table->foreignId('user_id')->nullable()->change();
        });

        Schema::table('two_factor_challenges', function (Blueprint $table) {
            $table->foreignUuid('external_system_id')
                  ->nullable()
                  ->after('system_id')
                  ->constrained('external_systems')
                  ->nullOnDelete();

            $table->boolean('sandbox_log')->default(false)->after('expires_at');
        });
    }

    public function down(): void
    {
        Schema::table('otp_dispatches', function (Blueprint $table) {
            $table->dropForeign(['external_system_id']);
            $table->dropColumn(['external_system_id', 'sandbox_log']);
            $table->foreignId('user_id')->nullable(false)->change();
        });

        Schema::table('two_factor_challenges', function (Blueprint $table) {
            $table->dropForeign(['external_system_id']);
            $table->dropColumn(['external_system_id', 'sandbox_log']);
        });
    }
};
