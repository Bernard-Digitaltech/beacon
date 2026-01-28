<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
  public function up(): void
  {
    Schema::table('beacon_signal', function (Blueprint $table) {
      $table->integer('battery')->nullable()->after('rssi');
    });
  }

  public function down(): void
  {
    Schema::table('beacon_signal', function (Blueprint $table) {
      $table->dropColumn('battery');
    });
  }
};