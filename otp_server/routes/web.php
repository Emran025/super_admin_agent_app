<?php

use App\Http\Controllers\Web\ExternalSystemPairingController;
use App\Http\Controllers\Web\PushTwoFactorTestController;
use App\Http\Controllers\Web\SmsGatewayTestController;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => redirect()->route('testbed.hub'));

/*
|--------------------------------------------------------------------------
| Testbed Hub
|--------------------------------------------------------------------------
*/

Route::get('/testbed', function () {
    $agent = \App\Models\Agent::first();
    $isAgentConnected = $agent ? $agent->isOnline() : false;
    $agentId = $agent ? $agent->agent_id : null;
    
    // Show QR code only when no agent has ever been paired.
    // Once an agent is in the database the pairing is permanent — the QR is
    // only needed for the very first setup. Use the "Unpair" action to reset.
    $showQrCode = !$agent;
    
    $qrCodeData = null;
    if ($showQrCode) {
        // Resolve public Reverb connection parameters for the mobile agent.
        // REVERB_HOST / REVERB_PORT are internal bind addresses; the agent
        // needs the public-facing host and port it can reach from outside.
        $reverbHost = request()->getHost();
        $reverbPort = request()->secure() ? 443 : (int) request()->getPort();
        $reverbAppKey = config('otp_server.reverb_app_key', 'super-admin-reverb-key');

        $qrCodeData = json_encode([
            'version'          => '1.0',
            'system_id'        => 'super-admin-system',
            'system_label'     => config('otp_server.system_label', 'SuperAdmin Server'),
            'pairing_endpoint' => url('/api'),
            'token'            => config('otp_server.pairing_token'),
            'expires_at'       => now()->addHours(24)->toIso8601String(),
            'capabilities'     => ['otp_gateway', 'two_fa', 'payment_observation'],
            'reverb_host'      => $reverbHost,
            'reverb_port'      => $reverbPort,
            'reverb_app_key'   => $reverbAppKey,
        ]);
    }
    
    return view('testbed.hub', compact('isAgentConnected', 'agentId', 'agent', 'showQrCode', 'qrCodeData'));
})->name('testbed.hub');

Route::post('/testbed/agent/unpair', function () {
    \App\Models\Agent::truncate();
    return redirect()->route('testbed.hub')->with('success', 'Mobile agent unpaired successfully. Secure credentials cleared.');
})->name('testbed.agent.unpair');

/*
|--------------------------------------------------------------------------
| System Pairing Testbed  —  /testbed/system-pairing
|--------------------------------------------------------------------------
|
| UI to create / manage "Test External Systems" (is_test = true).
| Generates a system_id, API token, and AES-256 encryption key shown once.
| Proves the External Gateway pairing ceremony before running the SMS or 2FA
| testbeds (which now encrypt their payloads and call /api/v1/external/...).
|
|   GET   /testbed/system-pairing         index()   — list test systems
|   POST  /testbed/system-pairing         store()   — create test system
|   POST  /testbed/system-pairing/{id}/delete  destroy() — delete test system
|
*/

Route::prefix('testbed/system-pairing')->group(function (): void {
    Route::get('/',            [ExternalSystemPairingController::class, 'index'])
         ->name('testbed.pairing');

    Route::post('/',           [ExternalSystemPairingController::class, 'store'])
         ->name('testbed.pairing.store');

    Route::post('/{id}/delete', [ExternalSystemPairingController::class, 'destroy'])
         ->name('testbed.pairing.destroy');
});

/*
|--------------------------------------------------------------------------
| SMS Gateway Testbed  —  /testbed/sms-gateway
|--------------------------------------------------------------------------
|
| Simulates a third-party application that delegates SMS sending to the agent.
| Updated (Phase 11): acts as an external client — reads the default test
| ExternalSystem, encrypts the payload with AES-256-GCM, and calls
| POST /api/v1/external/otp to exercise the full encrypted gateway flow.
|
|   GET  /testbed/sms-gateway          showPhoneForm()
|   POST /testbed/sms-gateway          dispatchOtp()
|   GET  /testbed/sms-gateway/verify   showVerifyForm()
|   POST /testbed/sms-gateway/verify   verifyOtp()
|
*/

Route::prefix('testbed/sms-gateway')->group(function (): void {
    Route::get('/',       [SmsGatewayTestController::class, 'showPhoneForm'])
         ->name('testbed.sms.phone');

    Route::post('/',      [SmsGatewayTestController::class, 'dispatchOtp'])
         ->name('testbed.sms.dispatch');

    Route::get('/verify', [SmsGatewayTestController::class, 'showVerifyForm'])
         ->name('testbed.sms.verify.form');

    Route::post('/verify', [SmsGatewayTestController::class, 'verifyOtp'])
         ->name('testbed.sms.verify');
});

/*
|--------------------------------------------------------------------------
| 2FA Push Testbed  —  /testbed/push-2fa
|--------------------------------------------------------------------------
|
| Simulates an admin control panel requiring push approval from the agent.
| Updated (Phase 11): acts as an external client — encrypts the payload and
| calls POST /api/v1/external/login to verify the full gateway flow.
|
|   GET  /testbed/push-2fa             showLoginForm()
|   POST /testbed/push-2fa             submitLogin()
|   GET  /testbed/push-2fa/waiting     showWaiting()
|   GET  /testbed/push-2fa/poll        pollStatus()
|
*/

Route::prefix('testbed/push-2fa')->group(function (): void {
    Route::get('/',        [PushTwoFactorTestController::class, 'showLoginForm'])
         ->name('testbed.push.login');

    Route::post('/',       [PushTwoFactorTestController::class, 'submitLogin'])
         ->name('testbed.push.submit');

    Route::get('/waiting', [PushTwoFactorTestController::class, 'showWaiting'])
         ->name('testbed.push.waiting');

    Route::get('/poll',    [PushTwoFactorTestController::class, 'pollStatus'])
         ->name('testbed.push.poll');
});
