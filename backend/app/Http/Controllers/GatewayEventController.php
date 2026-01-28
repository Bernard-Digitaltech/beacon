<?php

namespace App\Http\Controllers;

use App\Models\GatewayEvent;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class GatewayEventController extends Controller
{

  public  function getLatestEvents()
  {
    $events = GatewayEvent::latest()->take(50)->get();

    return response()->json([
      'status' => true,
      'message' => 'Latest gateway events fetched successfully',
      'data' => $events
    ]);
  }

  public function store(Request $req)
  {
      $data = $req->all();
        
        $validator = Validator::make($data, [
            'user_id'    => 'required|string',
            'phone_id'   => 'required|string',
            'event_type' => 'required|string',
            'details'    => 'nullable', 
            'timestamp'  => 'required', 
        ]);

      if ($validator->fails()) {
        return response()->json([
          'status' => false,
          'error'  => 'Validation Failed',
          'messages' => $validator->errors()
        ], 422);
      }

      $gatewayEvent = GatewayEvent::create([
            'user_id'     => $data['user_id'],
            'phone_id'    => $data['phone_id'],
            'event_type'  => $data['event_type'],
            'metadata'    => $data['details'] ?? [], 
            'captured_at' => $data['timestamp'],  
        ]);

      return response()->json([
          'status' => true,
          'message' => 'Gateway event logged successfully',
          'data' => $gatewayEvent
      ]);
  }
}