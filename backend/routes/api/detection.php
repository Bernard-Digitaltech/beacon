<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\DetectionController;

Route::post('/detection/report', [DetectionController::class, 'handle']);
