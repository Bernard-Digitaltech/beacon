<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Shift;

class ShiftSeeder extends Seeder
{
    public function run(): void
    {
        Shift::updateOrCreate(['name' => 'Morning'], ['start_time' => '08:00:00', 'end_time' => '17:00:00']);
        Shift::updateOrCreate(['name' => 'Afternoon'], ['start_time' => '16:00:00', 'end_time' => '00:00:00']);
        Shift::updateOrCreate(['name' => 'Midnight'], ['start_time' => '00:00:00', 'end_time' => '08:00:00']);
    }
}