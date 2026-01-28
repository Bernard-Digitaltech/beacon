<?php

namespace App\Http\Controllers;

use App\Jobs\LogBeaconDetection;
use App\Models\Beacon;
use App\Models\GatewayEvent;
use App\Models\Shift;
use App\Http\Controllers\GatewayEventController;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

class DetectionController extends Controller
{

  public function handle(Request $request)
  {
    $payload = $request -> all();

    if (isset($payload['type']) && $payload['type'] === 'gateway_event') {
      $gatewayController = new GatewayEventController();
      return $gatewayController ->store($request);
      
    } else if (isset($payload['type']) && $payload['type'] === 'beacon_detection') {
      return $this ->handleBeaconDetection($request);

    } else {
      return response()-> json([
        'error'   => 'Bad Request',
          'message' => 'Unknown detection type'
      ], 400);
    }
  }

  public function handleBeaconDetection(Request $request)
  {
    try {
      $data = $request -> validate([
        'user_id'     => 'required|string',
        'phone_id'    => 'required|string',
        'beacon_mac'  => 'required|string',
        'rssi'        => 'required|integer',
        'timestamp'   => 'required|date',
        'is_initial'  => 'required|boolean',
        'battery'     => 'nullable|integer'
      ]);

      $beacon = Beacon::where('beacon_mac', $data['beacon_mac']) ->first();
      if ($beacon) {
        $status = ($data['battery'] !== null && $data['battery'] < 20) ? 'warning' : 'active';
            $beacon->update([
              'battery_level' => $data['battery'] ?? $beacon->battery_level,
              'last_seen_at' => now(),
              'status' => $status
            ]);
        } else {
            return response()->json(['error' => 'Beacon not registered'], 404);
        }


      // Generate a temporary Validation Token
      $valToken = Str::random(32);
      // Dispatch async job
      try {
          LogBeaconDetection::dispatch(array_merge($data, ['validation_token' => $valToken]));
      } catch (\Exception $e) {
          Log::error('Failed to dispatch LogBeaconDetection job', [
              'data' => $data,
              'message' => $e->getMessage(),
          ]);
      }

      return response()->json([
        'status'       => 'processed',
        'trigger_noti' => $data['is_initial'], 
        'params'       => [
          'user_id' => $data['user_id'],
          'mac'     => $beacon->beacon_mac,
          'loc'     => $beacon->location_name,
          'rssi'    => 'Dynamic',
          'token'   => $valToken, 
          'time'    => now('Asia/Kuala_Lumpur')->toDateTimeString()
          ]
        ]);
    } catch (\Exception $e) {
      return response()-> json([
        'error'   => 'Internal Server Error',
          'message' => $e->getMessage()
      ], 500);
    } 
  }

}