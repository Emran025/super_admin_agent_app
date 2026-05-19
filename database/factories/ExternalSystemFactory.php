<?php

namespace Database\Factories;

use App\Models\ExternalSystem;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Str;

/**
 * Factory for ExternalSystem model — Phase 11 testing infrastructure.
 *
 * Security invariants:
 * - api_token_hash is SHA-256(plaintext token). Plaintext is NEVER stored in the DB.
 * - encryption_key is stored via Crypt::encryptString(). Raw AES-256 key is never stored.
 *
 * For tests that need the plaintext credentials, use makeWithCredentials() which
 * returns [$system, $plainToken, $plainKey] so tests can build Authorization headers
 * and encrypt payloads independently.
 */
class ExternalSystemFactory extends Factory
{
    protected $model = ExternalSystem::class;

    public function definition(): array
    {
        $plainToken = Str::random(64);
        $rawKey     = random_bytes(32);
        $encKey     = base64_encode($rawKey);

        return [
            'name'           => $this->faker->company() . ' API',
            'api_token_hash' => hash('sha256', $plainToken),
            'encryption_key' => Crypt::encryptString($encKey),
            'capabilities'   => ['otp', 'super_admin_login'],
            'is_test'        => false,
            'last_used_at'   => null,
        ];
    }

    /**
     * Create a system and return [$system, $plainToken, $plainKey].
     *
     * This is the canonical helper for Feature tests: the returned credentials
     * can be used to build Authorization headers and encrypt payloads without
     * ever needing to retrieve them from the database.
     *
     * @param  array $overrides  Extra state to merge before creation.
     * @return array{0: ExternalSystem, 1: string, 2: string}
     */
    public function makeWithCredentials(array $overrides = []): array
    {
        $plainToken = Str::random(64);
        $rawKey     = random_bytes(32);
        $encKey     = base64_encode($rawKey);

        $system = $this->state(array_merge([
            'api_token_hash' => hash('sha256', $plainToken),
            'encryption_key' => Crypt::encryptString($encKey),
        ], $overrides))->create();

        return [$system, $plainToken, $encKey];
    }

    /**
     * State: a test/sandbox system (is_test = true).
     */
    public function test(): static
    {
        return $this->state(['is_test' => true]);
    }

    /**
     * State: a system with only the 'otp' capability.
     */
    public function otpOnly(): static
    {
        return $this->state(['capabilities' => ['otp']]);
    }

    /**
     * State: a system with no capabilities (used for negative capability tests).
     */
    public function noCapabilities(): static
    {
        return $this->state(['capabilities' => []]);
    }
}
