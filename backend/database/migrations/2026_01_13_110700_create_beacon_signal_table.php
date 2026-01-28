<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{

  public function up(): void
  {
    Schema::create('beacon_signal', function (Blueprint $table) {
      $table->id();
      $table->string('user_id')->index();
      $table->string('phone_id')->index(); 
      $table->string('beacon_mac')->index();
      $table->integer('rssi'); 
      $table->dateTime('timestamp');
      $table->boolean('is_initial')->default(false);
      $table->timestamps();

      $table->index(['user_id', 'created_at']);
    });
  }

  public function down(): void
  {
    Schema::dropIfExists('beacon_signal');
  }

};
