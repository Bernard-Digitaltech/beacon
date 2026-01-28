<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('beacons', function (Blueprint $table) {
            $table->id();
            $table->string('beacon_mac')->unique();
            $table->string('location_name');
            $table->integer('range_meters')->default(5);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('beacons');
    }
};
