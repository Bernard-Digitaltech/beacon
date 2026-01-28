<?php

namespace App\Jobs;

use App\Models\BeaconDetection;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class LogBeaconDetection implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected array $data;

    /**
     * Maximum tries and backoff in seconds
     */
    public $tries = 5;
    public $backoff = 5;

    public function __construct(array $data)
    {
        $this->data = $data;
    }

    public function handle(): void
    {
        try {
            BeaconDetection::create($this->data);
        } catch (\Exception $e) {
            Log::error('BeaconDetection job failed', [
                'data' => $this->data,
                'message' => $e->getMessage(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(),
            ]);
        }
    }

    public function failed(\Exception $exception): void
    {
        // Optional: notify or log if job permanently fails
        Log::error('BeaconDetection job permanently failed', [
            'data' => $this->data,
            'message' => $exception->getMessage(),
            'line' => $exception->getLine(),
        ]);
    }
}
