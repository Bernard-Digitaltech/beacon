<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class BeaconDetection extends Model
{
  protected $table = 'beacon_signal';
  
  protected $fillable = [
    'user_id',
    'phone_id',
    'beacon_mac',
    'rssi',
    'battery',
    'timestamp',
    'is_initial'
  ];

  public function beacon()
  {
    return $this ->belongsTo(Beacon::class, 'beacon_mac', 'beacon_mac');
  }
}