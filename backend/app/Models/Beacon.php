<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Beacon extends Model
{
    protected $fillable = [
        'beacon_mac',
        'location_name',
        'range_meters',
        'battery_level',
        'last_seen_at',
        'status',
    ];

    protected $casts = [
        'last_seen_at' => 'datetime',
    ];

    public function signals()
    {
        return $this->hasMany(BeaconDetection::class, 'beacon_mac', 'beacon_mac');
    }

    public function attendance()
    {
        return $this->hasMany(Attendance::class);
    }
}
