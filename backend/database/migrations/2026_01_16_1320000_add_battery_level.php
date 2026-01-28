<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{

  public function up(): void
  {
    Schema::table('beacons', function (Blueprint $table) {
      $table->integer('battery_level')->nullable()->after('location_name');
      $table->timestamp('last_seen_at')->nullable()->after('battery_level');
      $table->enum('status', ['active', 'warning', 'offline'])->default('offline')->after('last_reported_by');
      
      $table->index('last_seen_at');
    });
  }

  public function down(): void
  {
    Schema::table('beacons', function (Blueprint $table) {
      $table->dropColumn(['battery_level', 'last_seen_at', 'status']);
    });
  }
};