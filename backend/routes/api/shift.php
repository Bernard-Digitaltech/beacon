<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ShiftController;

Route::get('/shifts', [ShiftController::class, 'getShiftTime']);