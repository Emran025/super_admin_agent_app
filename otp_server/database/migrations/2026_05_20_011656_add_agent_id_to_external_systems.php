<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('external_systems', function (Blueprint $table) {
            $table->string('agent_id')->nullable()->after('is_test');
            $table->index('agent_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('external_systems', function (Blueprint $table) {
            $table->dropIndex(['agent_id']);
            $table->dropColumn('agent_id');
        });
    }
};
