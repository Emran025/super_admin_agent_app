<?php

use App\Http\Controllers\Api\AgentHeartbeatController;
use App\Http\Controllers\Api\AgentReportController;
use App\Http\Controllers\Api\BroadcastingAuthController;
use App\Http\Controllers\Api\External\LoginApprovalController;
use App\Http\Controllers\Api\External\OtpGatewayController;
use App\Http\Controllers\Api\OtpCommandController;
use App\Http\Controllers\Api\PairingController;
use App\Http\Controllers\Api\PushChallengeController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| OTP Server API Routes — v1
|--------------------------------------------------------------------------
|
| All routes here are prefixed with /api automatically by Laravel.
|
| ── Agent Routes (ECDSA-signed) ──────────────────────────────────────────
|
|   POST  /api/v1/pair
|     ↳ PairingController::pair()
|
|   POST  /api/v1/broadcasting/auth
|     ↳ BroadcastingAuthController::auth()
|
|   GET   /api/v1/otp-commands/{commandId}
|     ↳ OtpCommandController::show()
|
|   POST  /api/v1/otp-commands/{commandId}/report
|     ↳ AgentReportController::report()
|
|   GET   /api/v1/push-challenges/{challengeId}
|     ↳ PushChallengeController::show()
|
|   POST  /api/v1/push-challenges/{challengeId}/respond
|     ↳ PushChallengeController::respond()
|
|   POST  /api/v1/agent/heartbeat
|     ↳ AgentHeartbeatController::heartbeat()
|
| ── External Gateway Routes (AES-256-GCM encrypted) ─────────────────────
|
|   POST  /api/v1/external/otp
|     ↳ OtpGatewayController::dispatch()
|     ↳ Middleware: auth.external, capability:otp
|     ↳ Body: { encrypted_payload, iv, tag }
|     ↳ Decrypted: { phone_number, message_body }
|     ↳ Response: 202 { command_id }
|
|   POST  /api/v1/external/login
|     ↳ LoginApprovalController::challenge()
|     ↳ Middleware: auth.external, capability:super_admin_login
|     ↳ Body: { encrypted_payload, iv, tag }
|     ↳ Decrypted: { username, context_label? }
|     ↳ Response: 202 { challenge_id }
|
*/

// ── Hub live-status polling (no auth — read-only, rate-limited by page load) ──
Route::get('/agent-status', function () {
    $agent = \App\Models\Agent::first();
    if (!$agent) {
        return response()->json(['paired' => false, 'online' => false, 'last_seen_at' => null, 'last_seen_human' => 'No agent paired']);
    }
    return response()->json([
        'paired'          => true,
        'online'          => $agent->isOnline(),
        'last_seen_at'    => $agent->last_seen_at?->toIso8601String(),
        'last_seen_human' => $agent->last_seen_at ? $agent->last_seen_at->diffForHumans() : 'Never — no heartbeat received yet',
    ]);
});

Route::prefix('v1')->group(function (): void {

    // ── Agent routes (no auth middleware — ECDSA signatures protect these) ──
    Route::post('/pair', [PairingController::class, 'pair']);
    Route::post('/broadcasting/auth', [BroadcastingAuthController::class, 'auth']);
    Route::get('/otp-commands/{commandId}', [OtpCommandController::class, 'show']);
    Route::post('/otp-commands/{commandId}/report', [AgentReportController::class, 'report']);
    Route::get('/push-challenges/{challengeId}', [PushChallengeController::class, 'show']);
    Route::post('/push-challenges/{challengeId}/respond', [PushChallengeController::class, 'respond']);

    // ── Agent heartbeat — keeps last_seen_at fresh while the WS stays alive ──
    Route::post('/agent/heartbeat', [AgentHeartbeatController::class, 'heartbeat']);

    // ── Agent External System Link Routes ──
    Route::post('/agent/link-system', [PairingController::class, 'linkSystem']);
    Route::post('/agent/unlink-system', [PairingController::class, 'unlinkSystem']);
    Route::get('/agent/linked-systems', [PairingController::class, 'linkedSystems']);

    // ── External system gateway (Constraint 2.1 — AES-256-GCM payload encryption) ──
    Route::prefix('external')
        ->middleware('auth.external')
        ->group(function (): void {
            Route::post('/otp',   [OtpGatewayController::class, 'dispatch'])
                 ->middleware('capability:otp')
                 ->name('api.v1.external.otp');

            Route::post('/login', [LoginApprovalController::class, 'challenge'])
                 ->middleware('capability:super_admin_login')
                 ->name('api.v1.external.login');
        });
});
