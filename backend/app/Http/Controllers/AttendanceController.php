<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Attendance;

class AttendanceController extends Controller
{
    /**
     * Show a user's attendance history
     */
    public function history(Request $req)
    {
        $records = Attendance::with('beacon')
            ->where('user_id', $req->user()->id)
            ->orderBy('check_in', 'desc')
            ->get();

        return response()->json([
            'status' => true,
            'data' => $records
        ]);
    }
}
