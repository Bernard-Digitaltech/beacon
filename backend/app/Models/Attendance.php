<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Carbon\Carbon;

class Attendance extends Model
{
    protected $table = 'attendance';

    protected $fillable = [
        'user_id',
        'beacon_id',
        'check_in',
        'check_out',
        'duration_minutes',
        'status',
        'shift_date',
    ];

    protected $casts = [
        'check_in'  => 'datetime',
        'check_out' => 'datetime',
    ];

    protected $appends = ['duration_formatted'];

    public function getDurationFormattedAttribute()
    {
        if (!$this->duration_minutes) {
            return null; 
        }

        $hours = floor($this->duration_minutes / 60);
        $minutes = $this->duration_minutes % 60;

        return "{$hours} hrs {$minutes} mins";
    }

    public function setShiftDateAttribute($value)
    {
        $this->attributes['shift_date'] = Carbon::parse($value)->format('Y-m-d');
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function beacon()
    {
        return $this->belongsTo(Beacon::class);
    }

    public function logs()
    {
        return $this->hasMany(AttendanceLog::class);
    }
}