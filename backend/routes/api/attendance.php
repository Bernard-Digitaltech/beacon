<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AttendanceController;

Route::get('/attendance/history', [AttendanceController::class, 'history']);
