<?php

namespace Database\Factories;

use App\Models\Agent;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * Factory for Agent model — Phase 10 testing infrastructure.
 *
 * Default state uses the static deterministic EC P-256 test keypair so that
 * AgentReportWebhookTest can sign payloads with the corresponding private key
 * and expect verification to succeed.
 *
 * Static test keypair (prime256v1):
 * - Private key: TEST_PRIVATE_KEY_PEM constant in AgentReportWebhookTest
 * - Public key:  base64url(04 || X || Y) — the 65-byte uncompressed EC point
 *
 * Security note for reviewers: these keys exist ONLY in the test suite and are
 * committed to source control intentionally. They are never used in production.
 */
class AgentFactory extends Factory
{
    protected $model = Agent::class;

    /**
     * Base64url-encoded 65-byte uncompressed P-256 EC point for the test keypair.
     * Corresponds to TEST_PRIVATE_KEY_PEM in AgentReportWebhookTest.
     */
    public const TEST_PUBLIC_KEY_BASE64URL =
        'BJ2Ir_SK7LJcv9oyR8SAu5HliRnXzZ0L4TELaMElk6-8CPiolmqu9ra8w1I_CACL6zh-ccjZ3p7ixajr3SxUz9Y';

    public const TEST_PUBLIC_KEY_ID = '00000000-test-test-test-000000000001';

    public function definition(): array
    {
        return [
            'system_id'        => (string) Str::uuid(),
            'agent_id'         => (string) Str::uuid(),
            'agent_public_key' => self::TEST_PUBLIC_KEY_BASE64URL,
            'public_key_id'    => self::TEST_PUBLIC_KEY_ID,

            'capabilities'     => ['otp_gateway'],
            'paired_at'        => now(),
        ];
    }

    /**
     * State that uses a random throwaway keypair (public key only — not verifiable).
     * Use this when you want an agent row that will FAIL signature verification.
     */
    public function withRandomKey(): static
    {
        return $this->state([
            'agent_public_key' => rtrim(
                strtr(base64_encode(random_bytes(65)), '+/', '-_'),
                '='
            ),
            'public_key_id' => (string) Str::uuid(),
        ]);
    }
}
