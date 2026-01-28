<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AttendanceLog extends Model
{
    protected $fillable = [
        'attendance_id',
        'type',
        'timestamp'
    ];

    public function attendance()
    {
        return $this->belongsTo(Attendance::class);
    }
}
