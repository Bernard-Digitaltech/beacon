<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('beacon_signal', function (Blueprint $table) {
            $table->string('validation_token')->nullable()->unique()->after('is_initial');
            $table->boolean('is_active')->default(true); 
        });
    }

    public function down(): void
    {
        Schema::table('beacon_signals', function (Blueprint $table) {
            $table->dropColumn(['validation_token', 'is_active']);
        });
    }
};