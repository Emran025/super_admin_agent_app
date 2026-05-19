<?php

use App\Http\Controllers\Web\PushTwoFactorTestController;
use App\Http\Controllers\Web\SmsGatewayTestController;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => redirect()->route('testbed.hub'));

/*
|--------------------------------------------------------------------------
| Testbed Hub
|--------------------------------------------------------------------------
|
| Landing page with two clear sections, each explaining the role being
| tested and linking to the dedicated testbed for that role.
|
*/

Route::get('/testbed', fn () => view('testbed.hub'))->name('testbed.hub');

/*
|--------------------------------------------------------------------------
| SMS Gateway Testbed  —  /testbed/sms-gateway
|--------------------------------------------------------------------------
|
| Simulates a third-party application that cannot send SMS itself and
| delegates to the paired Super Admin Agent as an SMS gateway.
|
| Role under test  : Agent as SMS Gateway (otp_gateway capability)
| Agent action     : Agent receives OTP dispatch via Reverb and sends real SMS
| User action      : Enter recipient phone → receive SMS → enter code → verified
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
| Simulates an admin control panel that requires explicit push approval
| from the paired Super Admin Agent before granting login access.
|
| Role under test  : Agent as Personal Authenticator (two_fa capability)
| Agent action     : Agent receives challenge via Reverb → shows Approve/Reject
| User action      : Enter dummy credentials → page waits → agent approves → access granted
|
| Dummy credentials: username=admin / password=testbed
|
|   GET  /testbed/push-2fa             showLoginForm()
|   POST /testbed/push-2fa             submitLogin()
|   GET  /testbed/push-2fa/waiting     showWaiting()   ← browser subscribes to Reverb here
|   GET  /testbed/push-2fa/poll        pollStatus()    ← AJAX safety-net
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
