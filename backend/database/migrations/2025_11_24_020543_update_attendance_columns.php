<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('attendance', function (Blueprint $table) {
            $table->timestamp('check_in')->nullable()->change();
            $table->timestamp('check_out')->nullable()->change();
            $table->integer('duration_minutes')->nullable()->change();
            $table->date('shift_date')->nullable(false)->default(now()->toDateString());
        });
    }

    public function down(): void
    {
        Schema::table('attendance', function (Blueprint $table) {
            $table->timestamp('check_in')->nullable(false)->change();
            $table->timestamp('check_out')->nullable(false)->change();
            $table->integer('duration_minutes')->nullable(false)->change();
            $table->dropColumn('shift_date');
        });
    }

};
