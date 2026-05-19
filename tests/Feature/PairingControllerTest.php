<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * PairingControllerTest — POST /api/v1/pair
 *
 * Covers the full pairing ceremony:
 *   1. Valid pairing token and well-formed public key → HTTP 201 with correct fields.
 *   2. Invalid pairing token → HTTP 401.
 *   3. Missing required fields → HTTP 422 (validation failure).
 *   4. Re-pairing with the same public_key_id updates the existing record (idempotent).
 *   5. Pairing response includes Reverb connection parameters.
 */
class PairingControllerTest extends TestCase
{
    use RefreshDatabase;

    /**
     * A deterministic 65-byte uncompressed P-256 EC point in base64url encoding.
     * The same test key used in AgentReportWebhookTest / AgentFactory.
     */
    private const TEST_PUBLIC_KEY = 'BJ2Ir_SK7LJcv9oyR8SAu5HliRnXzZ0L4TELaMElk6-8CPiolmqu9ra8w1I_CACL6zh-ccjZ3p7ixajr3SxUz9Y';
    private const TEST_PUBLIC_KEY_ID = '00000000-test-test-test-000000000001';

    // =========================================================================
    // Test 1 — Valid pairing returns 201 with all expected fields
    // =========================================================================

    #[Test]
    public function valid_pairing_returns_201_with_expected_fields(): void
    {
        $response = $this->postJson('/api/v1/pair', [
            'pairing_token'     => config('otp_server.pairing_token'),
            'public_key_base64' => self::TEST_PUBLIC_KEY,
            'public_key_id'     => self::TEST_PUBLIC_KEY_ID,
        ]);

        $response->assertStatus(201)
                 ->assertJsonStructure([
                     'agent_id',
                     'system_id',
                     'system_label',
                     'base_url',
                     'granted_capabilities',
                     'paired_at',
                     'reverb_host',
                     'reverb_port',
                     'reverb_app_key',
                 ]);

        // Verify the agent record was created in the database.
        $this->assertDatabaseHas('agents', [
            'public_key_id'    => self::TEST_PUBLIC_KEY_ID,
            'agent_public_key' => self::TEST_PUBLIC_KEY,
        ]);

        // Capabilities default to otp_gateway.
        $data = $response->json();
        $this->assertContains('otp_gateway', $data['granted_capabilities']);
    }

    // =========================================================================
    // Test 2 — Invalid pairing token returns 401
    // =========================================================================

    #[Test]
    public function invalid_pairing_token_returns_401(): void
    {
        $response = $this->postJson('/api/v1/pair', [
            'pairing_token'     => 'wrong-token-that-does-not-match',
            'public_key_base64' => self::TEST_PUBLIC_KEY,
            'public_key_id'     => self::TEST_PUBLIC_KEY_ID,
        ]);

        $response->assertStatus(401)
                 ->assertJson(['error' => 'Invalid pairing token.']);

        $this->assertDatabaseMissing('agents', [
            'public_key_id' => self::TEST_PUBLIC_KEY_ID,
        ]);
    }

    // =========================================================================
    // Test 3 — Missing required fields returns 422
    // =========================================================================

    #[Test]
    public function missing_required_fields_returns_422(): void
    {
        $response = $this->postJson('/api/v1/pair', [
            'pairing_token' => config('otp_server.pairing_token'),
            // public_key_base64 and public_key_id are missing
        ]);

        $response->assertStatus(422)
                 ->assertJsonValidationErrors(['public_key_base64', 'public_key_id']);
    }

    // =========================================================================
    // Test 4 — Re-pairing with the same public_key_id updates the record (idempotent)
    // =========================================================================

    #[Test]
    public function re_pairing_with_same_public_key_id_is_idempotent(): void
    {
        $payload = [
            'pairing_token'     => config('otp_server.pairing_token'),
            'public_key_base64' => self::TEST_PUBLIC_KEY,
            'public_key_id'     => self::TEST_PUBLIC_KEY_ID,
        ];

        // First pairing
        $first = $this->postJson('/api/v1/pair', $payload);
        $first->assertStatus(201);

        // Second pairing with same public_key_id — must not create duplicate
        $second = $this->postJson('/api/v1/pair', $payload);
        $second->assertStatus(201);

        // Only one agent record should exist for this key.
        $this->assertDatabaseCount('agents', 1);
    }

    // =========================================================================
    // Test 5 — Response includes Reverb connection parameters
    // =========================================================================

    #[Test]
    public function pairing_response_includes_reverb_connection_parameters(): void
    {
        $response = $this->postJson('/api/v1/pair', [
            'pairing_token'     => config('otp_server.pairing_token'),
            'public_key_base64' => self::TEST_PUBLIC_KEY,
            'public_key_id'     => self::TEST_PUBLIC_KEY_ID,
        ]);

        $response->assertStatus(201);

        $data = $response->json();
        $this->assertArrayHasKey('reverb_host', $data);
        $this->assertArrayHasKey('reverb_port', $data);
        $this->assertArrayHasKey('reverb_app_key', $data);

        // reverb_port must be an integer.
        $this->assertIsInt($data['reverb_port']);
    }
}
