<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('gateway_events', function (Blueprint $table) {
            $table->id();
            $table->string('user_id')->index();
            $table->string('phone_id')->index(); 
            $table->string('event_type'); 
            $table->json('metadata')->nullable(); 
            $table->timestamp('captured_at');
            $table->timestamps();
        });
    }

    public function down(): void {
        Schema::dropIfExists('beacon_events');
    }
};