<?php

namespace Database\Factories;

use App\Models\OtpDispatch;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

/**
 * Factory for OtpDispatch model — Phase 10 testing infrastructure.
 *
 * Security invariants enforced in this factory (mirrors production behaviour):
 * - otp_hash is ALWAYS a bcrypt hash produced by Hash::make(). Plaintext '123456'
 *   is used only as the known test value so tests can call Hash::check('123456', $hash).
 * - Plaintext '123456' is NEVER stored in any column. If you add a column and
 *   accidentally store the plaintext, the Phase 10 CI security gate will catch it.
 *
 * Usage in tests:
 *   $dispatch = OtpDispatch::factory()->create();
 *   $this->assertTrue(Hash::check('123456', $dispatch->otp_hash)); // passes
 *   $this->assertNotEquals('123456', $dispatch->otp_hash);          // passes
 */
class OtpDispatchFactory extends Factory
{
    protected $model = OtpDispatch::class;

    public function definition(): array
    {
        return [
            'user_id'      => User::factory(),
            'phone_number' => $this->faker->e164PhoneNumber(),
            'otp_hash'     => Hash::make('123456'),
            'status'       => 'pending',
            'expires_at'   => now()->addMinutes(5),
        ];
    }

    /**
     * State: dispatch record that has already expired.
     * Use to test that expired dispatches are rejected even with a correct OTP.
     */
    public function expired(): static
    {
        return $this->state([
            'expires_at' => now()->subMinute(),
        ]);
    }

    /**
     * State: dispatch in 'dispatched' status (FCM push already sent).
     */
    public function dispatched(): static
    {
        return $this->state([
            'status' => 'dispatched',
        ]);
    }

    /**
     * State: dispatch in 'delivered' status (agent reported success).
     */
    public function delivered(): static
    {
        return $this->state([
            'status' => 'delivered',
        ]);
    }
}
