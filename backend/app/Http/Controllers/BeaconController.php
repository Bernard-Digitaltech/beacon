<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Beacon;
use App\Models\Attendance;
use App\Models\AttendanceLog;
use Illuminate\Http\Request;
use Carbon\Carbon;

class BeaconController extends Controller
{

    public function getAllBeacons()
    {
        $beacons = Beacon::all();

        return response()->json([
            'status' => true,
            'message' => 'Beacons fetched successfully',
            'data' => $beacons
        ]);
    }

    public function register(Request $req)
    {
        $validated = $req->validate([
            'beacon_mac' => 'required|string|unique:beacons,beacon_mac',
            'location_name' => 'required|string'
        ]);

        $beacon = Beacon::create(array_merge($validated, ['battery_level' => -1]));

        return response()->json([
            'status' => true,
            'message' => 'Beacon registered successfully',
            'data' => $beacon
        ]);
    }

    /**
     * Auto IN/OUT detection (no action needed from frontend)
     */
    public function detected(Request $req)
    {
        $validated = $req->validate([
            'device_uuid' => 'required|string',
            'beacon_mac' => 'required|string'
        ]);

        $user = User::where('device_uuid', $validated['device_uuid'])->first();
        $beacon = Beacon::where('beacon_mac', $validated['beacon_mac'])->first();

        if (!$user || !$beacon) {
            return response()->json(['error' => 'User or Beacon not recognized'], 404);
        }

        // 1️⃣ Determine today’s shift date (support night shift)
        $now = Carbon::now('Asia/Kuala_Lumpur');
        $shiftDate = $now->hour >= 21 ? $now->copy()->subDay()->toDateString() : $now->toDateString();

        // 2️⃣ Get or create the shift (Attendance)
        $attendance = Attendance::firstOrCreate(
            ['user_id' => $user->id, 'beacon_id' => $beacon->id, 'shift_date' => $shiftDate],
            ['check_in' => null, 'check_out' => null, 'status' => 'in-progress']
        );

        // 3️⃣ Get last log for this shift
        $lastLog = $attendance->logs()->latest()->first();

        // 4️⃣ Decide IN or OUT
        if (!$lastLog) {
            // First ever log → IN
            return $this->logIn($attendance, $now);
        }

        if ($lastLog->type === 'OUT') {
            return $this->logIn($attendance, $now);
        }

        if ($lastLog->type === 'IN') {
            return $this->logOut($attendance, $now);
        }

        return response()->json(['error' => 'Unknown state'], 400);
    }

    
    public function checkStatus(Request $req)
    {
        $req->validate([
            'device_uuid' => 'required|string',
            'beacon_mac' => 'required|string'
        ]);

        $user = User::where('device_uuid', $req->device_uuid)->first();
        $beacon = Beacon::where('beacon_mac', $req->beacon_mac)->first();

        if (!$user || !$beacon) {
            return response()->json(['status' => 'error', 'message' => 'User/Beacon not found'], 404);
        }

        $now = Carbon::now('Asia/Kuala_Lumpur');
        $shiftDate = $now->hour >= 21 ? $now->copy()->subDay()->toDateString() : $now->toDateString();

        $attendance = Attendance::where('user_id', $user->id)
            ->where('beacon_id', $beacon->id)
            ->where('shift_date', $shiftDate)
            ->first();

        if (!$attendance) {
            return response()->json([
                'status' => true,
                'current_state' => 'NONE',
                'next_action' => 'IN',
                'message' => 'You have not checked in yet.'
            ]);
        }

        $lastLog = $attendance->logs()->latest()->first();

        if ($lastLog && $lastLog->type === 'IN') {
            return response()->json([
                'status' => true,
                'current_state' => 'IN',
                'check_in_time' => Carbon::parse($attendance->check_in)->format('h:i A'),
                'next_action' => 'OUT',
                'message' => 'Class in progress.'
            ]);
        }

        return response()->json([
            'status' => true,
            'current_state' => 'OUT',
            'next_action' => 'IN',
            'message' => 'Ready to check in again.'
        ]);
    }

    /**
     * Handle IN (check-in)
     */
    private function logIn($attendance, $now)
    {
        // Save first check_in if not set
        if (!$attendance->check_in) {
            $attendance->check_in = $now->toDateTimeString();
        }


        //Reset check_out and duration in case of re-IN
        if ($attendance->check_out) {
            $attendance->check_out = null;
            $attendance->duration_minutes = null;
        }


        //Reset check_out and duration in case of re-IN
        if ($attendance->check_out) {
            $attendance->check_out = null;
            $attendance->duration_minutes = null;
        }

        $attendance->status = 'in-progress';
        $attendance->save();

        // Create log
        AttendanceLog::create([
            'attendance_id' => $attendance->id,
            'type' => 'IN',
            'timestamp' => $now->toDateTimeString(),
        ]);

        return response()->json([
            'action' => 'IN',
            'message' => 'Checked IN',
            'time' => $now->format('h:i A'), // Return readable time
            'shift_date' => $attendance->shift_date
        ]);
    }

    /**
     * Handle OUT (check-out)
     */
    private function logOut($attendance, $now)
    {
        $attendance->check_out = $now->toDateTimeString();

        $checkInTime = Carbon::parse($attendance->check_in);
        $totalMinutes = $attendance->check_in->diffInMinutes($now);
        
        $attendance->duration_minutes = $totalMinutes;
        $attendance->status = 'completed';
        $attendance->save();

        AttendanceLog::create([
            'attendance_id' => $attendance->id,
            'type' => 'OUT',
            'timestamp' => $now->toDateTimeString(),
        ]);

        // Format for App: "8 hrs 30 mins"
        $hours = floor($totalMinutes / 60);
        $minutes = $totalMinutes % 60;
        $readableDuration = "{$hours} hrs {$minutes} mins";

        return response()->json([
            'action' => 'OUT',
            'message' => 'Checked OUT',
            'time' => $now->format('h:i A'), 
            'total_minutes' => $totalMinutes,
            'duration_formatted' => $readableDuration
        ]);
    }
}