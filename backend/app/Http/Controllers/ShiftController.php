<?php

namespace App\Http\Controllers;

use App\Models\Shift;
use Illuminate\Http\Request;
use Carbon\Carbon;

class ShiftController extends Controller
{
  public function getShiftTime ()
  {
    $shifts = Shift::all();

    return response()->json([
      'status' => true,
      'message' => 'Shifts fetched successfully',
      'data' => $shifts
    ]);
  }
}