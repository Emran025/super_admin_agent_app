<?php

use App\Http\Controllers\Api\AgentReportController;
use App\Http\Controllers\Api\OtpCommandController;
use App\Http\Controllers\Api\PairingController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| OTP Server API Routes — v1
|--------------------------------------------------------------------------
|
| All routes here are prefixed with /api automatically by Laravel.
|
| Contract (must match the Flutter data layer):
|
|   POST  /api/v1/pair
|     ↳ PairingController::pair()
|     ↳ Body: {pairing_token, public_key_base64, public_key_id}
|     ↳ Header: X-FCM-Token
|
|   GET   /api/v1/otp-commands/{commandId}
|     ↳ OtpCommandController::show()
|     ↳ Returns full OtpDispatchCommandDto (agent calls this after FCM trigger)
|
|   POST  /api/v1/otp-commands/{commandId}/report
|     ↳ AgentReportController::report()
|     ↳ Body: {command_id, status, reported_at, nonce, agent_public_key_id, signature}
|     ↳ Full ECDSA-SHA256 P-256 signature verification + nonce replay prevention
|
*/

Route::prefix('v1')->group(function (): void {
    Route::post('/pair', [PairingController::class, 'pair']);

    Route::get('/otp-commands/{commandId}', [OtpCommandController::class, 'show']);
    Route::post('/otp-commands/{commandId}/report', [AgentReportController::class, 'report']);
});
