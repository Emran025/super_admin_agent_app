<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Pairing Token
    |--------------------------------------------------------------------------
    |
    | A shared secret distributed out-of-band to the mobile agent before the
    | pairing ceremony. The POST /v1/pair endpoint validates this token with
    | hash_equals() to prevent timing attacks.
    |
    | Set via environment variable OTP_PAIRING_TOKEN. This must be a high-entropy
    | random string (>= 32 bytes). Never commit a real value to source control.
    |
    */
    'pairing_token' => env('OTP_PAIRING_TOKEN', 'change-me-in-production'),

    /*
    |--------------------------------------------------------------------------
    | System Label
    |--------------------------------------------------------------------------
    |
    | Human-readable label returned in the pairing response. Displayed in the
    | mobile agent UI to identify which system this agent is paired to.
    |
    */
    'system_label' => env('OTP_SYSTEM_LABEL', 'OTP Testbed'),

    /*
    |--------------------------------------------------------------------------
    | OTP Expiry (minutes)
    |--------------------------------------------------------------------------
    |
    | How long an OTP dispatch record remains valid. After this window,
    | Hash::check() verification is refused regardless of correctness.
    |
    */
    'otp_expiry_minutes' => (int) env('OTP_EXPIRY_MINUTES', 5),

    /*
    |--------------------------------------------------------------------------
    | Reverb Connection Parameters (returned to agent during pairing)
    |--------------------------------------------------------------------------
    |
    | These values are read via config() so they are cached correctly in
    | production. Never use env() directly in controllers.
    |
    */
    'reverb_host'    => env('REVERB_HOST', 'localhost'),
    'reverb_port'    => (int) env('REVERB_PORT', 8080),
    'reverb_app_key' => env('REVERB_APP_KEY', 'super-admin-reverb-key'),
];
