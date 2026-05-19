<?php

use App\Http\Controllers\Auth\OtpVerificationController;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => redirect()->route('otp.verify.form'));

/*
|--------------------------------------------------------------------------
| OTP Verification Web Routes
|--------------------------------------------------------------------------
|
| Minimal testbed UI for push-based 2FA verification.
|
|   GET  /otp/verify   — Display the 6-digit OTP entry form
|   POST /otp/send     — Dispatch a new OTP to the paired agent via FCM
|   POST /otp/verify   — Validate the OTP code entered by the user
|
*/

Route::middleware('web')->group(function (): void {
    Route::get('/otp/verify', [OtpVerificationController::class, 'showVerificationForm'])
        ->name('otp.verify.form');

    Route::post('/otp/send', [OtpVerificationController::class, 'sendOtp'])
        ->name('otp.send');

    Route::post('/otp/verify', [OtpVerificationController::class, 'verifyOtp'])
        ->name('otp.verify');
});
