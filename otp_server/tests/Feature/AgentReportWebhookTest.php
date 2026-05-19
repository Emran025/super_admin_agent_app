<?php

namespace Tests\Feature;

use App\Models\Agent;
use App\Models\OtpDispatch;
use App\Services\CanonicalJsonService;
use Database\Factories\AgentFactory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * AgentReportWebhookTest — Phase 10 Step 2.3
 *
 * Tests the full signature verification and nonce replay prevention chain
 * on POST /api/v1/otp-commands/{commandId}/report.
 *
 * All four required test cases from the Phase 10 spec are implemented:
 *   1. valid_signature_is_accepted     — valid ECDSA-SHA256 P-256 signature → HTTP 200
 *   2. invalid_signature_is_rejected   — tampered signature → HTTP 401
 *   3. nonce_replay_is_rejected        — valid sig, replayed nonce → HTTP 409
 *   4. unknown_agent_is_rejected       — unknown public_key_id → HTTP 404
 *
 * Signing uses PHP's built-in openssl_sign() with the static test private key.
 * This is the same algorithm (ECDSA-SHA256 P-256) and DER output format that the
 * Flutter agent produces via pointycastle — so a passing test proves the
 * SignatureVerifierService correctly mirrors the Flutter signing contract.
 *
 * Static test keypair:
 * - Private key: TEST_PRIVATE_KEY_PEM constant below (prime256v1, testbed-only)
 * - Public key:  AgentFactory::TEST_PUBLIC_KEY_BASE64URL (base64url 65-byte EC point)
 *
 * These keys are committed to source control intentionally — they are test fixtures,
 * never production credentials.
 */
class AgentReportWebhookTest extends TestCase
{
    use RefreshDatabase;

    /**
     * EC P-256 (prime256v1) private key — TEST FIXTURE ONLY.
     * Corresponds to AgentFactory::TEST_PUBLIC_KEY_BASE64URL.
     * NEVER use this key outside of the test suite.
     */
    private const TEST_PRIVATE_KEY_PEM = <<<'PEM'
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgX/cu2y+Wv0dMTnr1
KQ3m2jM2ydpLp6hEu29EEztinr2hRANCAASdiK/0iuyyXL/aMkfEgLuR5YkZ182d
C+ExC2jBJZOvvAj4qJZqrva2vMNSPwgAi+s4fnHI2d6e4sWo690sVM/W
-----END PRIVATE KEY-----
PEM;

    private Agent $agent;
    private OtpDispatch $dispatch;

    protected function setUp(): void
    {
        parent::setUp();

        $this->agent    = Agent::factory()->create();
        $this->dispatch = OtpDispatch::factory()->dispatched()->create();
    }

    // =========================================================================
    // Test case 1 — Valid signature must be accepted (HTTP 200)
    // =========================================================================

    #[Test]
    public function valid_signature_is_accepted(): void
    {
        $payload = $this->buildReportPayload($this->dispatch->id, 'delivered');
        $payload['signature'] = $this->signPayload($payload);

        $response = $this->postJson(
            "/api/v1/otp-commands/{$this->dispatch->id}/report",
            $payload
        );

        $response->assertStatus(200)
                 ->assertJson(['status' => 'delivered']);

        $this->assertDatabaseHas('otp_dispatches', [
            'id'     => $this->dispatch->id,
            'status' => 'delivered',
        ]);

        $this->assertDatabaseHas('used_nonces', [
            'agent_id' => $this->agent->agent_id,
            'nonce'    => $payload['nonce'],
        ]);
    }

    // =========================================================================
    // Test case 2 — Invalid signature must be rejected (HTTP 401)
    // =========================================================================

    #[Test]
    public function invalid_signature_is_rejected(): void
    {
        $payload = $this->buildReportPayload($this->dispatch->id, 'delivered');
        // Produce a valid signature then corrupt the last 4 chars so verification fails
        $validSig = $this->signPayload($payload);
        $payload['signature'] = substr($validSig, 0, -4) . 'AAAA';

        $response = $this->postJson(
            "/api/v1/otp-commands/{$this->dispatch->id}/report",
            $payload
        );

        $response->assertStatus(401)
                 ->assertJson(['error' => 'Signature verification failed.']);

        $this->assertDatabaseMissing('otp_dispatches', [
            'id'     => $this->dispatch->id,
            'status' => 'delivered',
        ]);
    }

    // =========================================================================
    // Test case 3 — Nonce replay must be rejected (HTTP 409)
    // =========================================================================

    #[Test]
    public function nonce_replay_is_rejected(): void
    {
        $payload = $this->buildReportPayload($this->dispatch->id, 'delivered');
        $payload['signature'] = $this->signPayload($payload);

        // First request — consumes the nonce (writes it to used_nonces via DB transaction)
        $this->postJson("/api/v1/otp-commands/{$this->dispatch->id}/report", $payload)
             ->assertStatus(200);

        // Second dispatch record for the replay attempt (different command, same nonce)
        $dispatch2 = OtpDispatch::factory()->dispatched()->create();
        $replayPayload = array_merge($payload, [
            'command_id' => $dispatch2->id,
        ]);
        // Re-sign with the new command_id so the signature itself is valid —
        // the nonce guard must fire BEFORE signature verification reaches openssl_verify.
        $replayPayload['signature'] = $this->signPayload($replayPayload);

        // Second request carries the same nonce — must be rejected with HTTP 409.
        // The nonce was already consumed and recorded by the first successful request.
        $response = $this->postJson(
            "/api/v1/otp-commands/{$dispatch2->id}/report",
            $replayPayload
        );

        $response->assertStatus(409)
                 ->assertJson(['error' => 'Nonce already used — replay detected.']);
    }

    // =========================================================================
    // Test case 4 — Unknown agent must be rejected (HTTP 404)
    // =========================================================================

    #[Test]
    public function unknown_agent_is_rejected(): void
    {
        $payload = $this->buildReportPayload($this->dispatch->id, 'delivered');
        $payload['agent_public_key_id'] = (string) Str::uuid();
        $payload['signature'] = $this->signPayload($payload);

        $response = $this->postJson(
            "/api/v1/otp-commands/{$this->dispatch->id}/report",
            $payload
        );

        $response->assertStatus(404)
                 ->assertJson(['error' => 'Unknown agent.']);
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    /**
     * Builds a structurally valid OTP delivery report payload.
     * The 'signature' field is set to an empty string — call signPayload() to fill it.
     */
    private function buildReportPayload(string $commandId, string $status): array
    {
        return [
            'command_id'          => $commandId,
            'status'              => $status,
            'reported_at'         => now()->toIso8601String(),
            'nonce'               => bin2hex(random_bytes(16)),
            'agent_public_key_id' => AgentFactory::TEST_PUBLIC_KEY_ID,
            'signature'           => '',
        ];
    }

    /**
     * Signs the report payload with ECDSA-SHA256 P-256 — identical algorithm to
     * the Flutter agent's AndroidKeystoreSigningService / pointycastle (prime256v1).
     *
     * Signing input mirrors ExecuteSmsDispatchUseCase exactly:
     *   CanonicalJson({command_id, nonce, reported_at, status}) + "\n" + nonce + "\n" + reported_at
     *
     * Output: base64url-encoded DER-encoded ECDSA signature, no padding.
     */
    private function signPayload(array $payload): string
    {
        $canonicalJson = CanonicalJsonService::encode([
            'command_id'  => $payload['command_id'],
            'nonce'       => $payload['nonce'],
            'reported_at' => $payload['reported_at'],
            'status'      => $payload['status'],
        ]);

        $signingInput = $canonicalJson . "\n" . $payload['nonce'] . "\n" . $payload['reported_at'];

        $privateKey = openssl_pkey_get_private(self::TEST_PRIVATE_KEY_PEM);
        openssl_sign($signingInput, $derSignature, $privateKey, OPENSSL_ALGO_SHA256);

        return rtrim(strtr(base64_encode($derSignature), '+/', '-_'), '=');
    }
}
