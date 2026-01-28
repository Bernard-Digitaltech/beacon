<?php

use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {

    // Public routes
    require __DIR__.'/api/auth.php';
    require __DIR__.'/api/shift.php';
    require __DIR__.'/api/detection.php';
    require __DIR__.'/api/beacon.php';

    // Protected routes
    Route::middleware('auth:sanctum')->group(function () {

        require __DIR__.'/api/attendance.php';

    });

});
