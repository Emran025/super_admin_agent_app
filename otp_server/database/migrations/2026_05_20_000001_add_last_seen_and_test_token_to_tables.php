<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('agents', function (Blueprint $table) {
            $table->timestamp('last_seen_at')->nullable()->after('paired_at');
        });

        Schema::table('external_systems', function (Blueprint $table) {
            $table->text('test_token_encrypted')->nullable()->after('api_token_hash');
        });
    }

    public function down(): void
    {
        Schema::table('agents', function (Blueprint $table) {
            $table->dropColumn('last_seen_at');
        });

        Schema::table('external_systems', function (Blueprint $table) {
            $table->dropColumn('test_token_encrypted');
        });
    }
};
