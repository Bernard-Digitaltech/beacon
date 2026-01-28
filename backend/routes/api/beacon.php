<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\BeaconController;

Route::post('/beacon/register', [BeaconController::class, 'register']);
Route::post('/beacon/detected', [BeaconController::class, 'detected']);
Route::post('/beacon/check-status', [BeaconController::class, 'checkStatus']);
Route::get('/beacons', [BeaconController::class, 'getAllBeacons']);