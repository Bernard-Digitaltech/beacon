<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class GatewayEvent extends Model
{
    protected $fillable = [
        'user_id',
        'phone_id',
        'event_type',
        'metadata',
        'captured_at',
    ];

    protected $casts = [
        'metadata' => 'array',
        'captured_at' => 'datetime',
    ];
}