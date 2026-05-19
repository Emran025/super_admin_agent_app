<?php

namespace Tests\Unit;

use App\Services\CanonicalJsonService;
use App\Services\SignatureVerifierService;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * SignatureVerifierServiceTest
 *
 * Verifies the ECDSA-SHA256 P-256 signature verification logic in isolation.
 *
 * Uses the same static test keypair as AgentReportWebhookTest so signatures
 * produced here are guaranteed to match what the Flutter agent produces with
 * the corresponding Keystore key.
 *
 * Static test keypair (prime256v1) — committed intentionally, test-only:
 *   Private: TEST_PRIVATE_KEY_PEM (in this file)
 *   Public:  TEST_PUBLIC_KEY_BASE64URL (65-byte uncompressed P-256 point, base64url)
 */
class SignatureVerifierServiceTest extends TestCase
{
    private const TEST_PRIVATE_KEY_PEM = <<<'PEM'
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgX/cu2y+Wv0dMTnr1
KQ3m2jM2ydpLp6hEu29EEztinr2hRANCAASdiK/0iuyyXL/aMkfEgLuR5YkZ182d
C+ExC2jBJZOvvAj4qJZqrva2vMNSPwgAi+s4fnHI2d6e4sWo690sVM/W
-----END PRIVATE KEY-----
PEM;

    private const TEST_PUBLIC_KEY_BASE64URL =
        'BJ2Ir_SK7LJcv9oyR8SAu5HliRnXzZ0L4TELaMElk6-8CPiolmqu9ra8w1I_CACL6zh-ccjZ3p7ixajr3SxUz9Y';

    private SignatureVerifierService $verifier;

    protected function setUp(): void
    {
        parent::setUp();
        $this->verifier = new SignatureVerifierService();
    }

    // =========================================================================
    // Test 1 — Valid ECDSA-SHA256 signature verifies correctly
    // =========================================================================

    #[Test]
    public function valid_signature_verifies_successfully(): void
    {
        $signingInput = 'hello world signing input';
        $signature    = $this->sign($signingInput);

        $result = $this->verifier->verify(
            signingInput:       $signingInput,
            base64urlSignature: $signature,
            base64urlPublicKey: self::TEST_PUBLIC_KEY_BASE64URL,
        );

        $this->assertTrue($result);
    }

    // =========================================================================
    // Test 2 — Tampered signature fails verification
    // =========================================================================

    #[Test]
    public function tampered_signature_fails_verification(): void
    {
        $signingInput    = 'some signing input';
        $validSignature  = $this->sign($signingInput);
        $tamperedSig     = substr($validSignature, 0, -4) . 'AAAA';

        $result = $this->verifier->verify(
            signingInput:       $signingInput,
            base64urlSignature: $tamperedSig,
            base64urlPublicKey: self::TEST_PUBLIC_KEY_BASE64URL,
        );

        $this->assertFalse($result);
    }

    // =========================================================================
    // Test 3 — Wrong signing input fails verification
    // =========================================================================

    #[Test]
    public function wrong_signing_input_fails_verification(): void
    {
        $signature = $this->sign('original input');

        $result = $this->verifier->verify(
            signingInput:       'tampered input',
            base64urlSignature: $signature,
            base64urlPublicKey: self::TEST_PUBLIC_KEY_BASE64URL,
        );

        $this->assertFalse($result);
    }

    // =========================================================================
    // Test 4 — Invalid (random) public key returns false (not an exception)
    // =========================================================================

    #[Test]
    public function invalid_public_key_returns_false(): void
    {
        $signingInput = 'test input';
        $signature    = $this->sign($signingInput);

        // A random 65-byte value that starts with 0x04 but is not a valid P-256 point
        $badKey = rtrim(strtr(base64_encode("\x04" . str_repeat("\xFF", 64)), '+/', '-_'), '=');

        $result = $this->verifier->verify(
            signingInput:       $signingInput,
            base64urlSignature: $signature,
            base64urlPublicKey: $badKey,
        );

        $this->assertFalse($result);
    }

    // =========================================================================
    // Test 5 — OTP report signing input round-trip (mirrors production contract)
    // =========================================================================

    #[Test]
    public function otp_report_signing_input_round_trip(): void
    {
        $commandId  = 'cmd-' . bin2hex(random_bytes(8));
        $nonce      = bin2hex(random_bytes(16));
        $reportedAt = now()->toIso8601String();
        $status     = 'delivered';

        $signingInput = $this->verifier->buildOtpReportSigningInput(
            commandId:  $commandId,
            nonce:      $nonce,
            reportedAt: $reportedAt,
            status:     $status,
        );

        $signature = $this->sign($signingInput);

        $result = $this->verifier->verify(
            signingInput:       $signingInput,
            base64urlSignature: $signature,
            base64urlPublicKey: self::TEST_PUBLIC_KEY_BASE64URL,
        );

        $this->assertTrue($result);
    }

    // =========================================================================
    // Test 6 — buildOtpReportSigningInput sorts keys alphabetically
    // =========================================================================

    #[Test]
    public function build_otp_report_signing_input_has_sorted_canonical_json(): void
    {
        $signingInput = $this->verifier->buildOtpReportSigningInput(
            commandId:  'cmd-001',
            nonce:      'nonce-abc',
            reportedAt: '2024-06-01T12:00:00Z',
            status:     'failed',
        );

        // The canonical JSON portion must have keys sorted: command_id, nonce, reported_at, status
        $this->assertStringStartsWith(
            '{"command_id":"cmd-001","nonce":"nonce-abc","reported_at":"2024-06-01T12:00:00Z","status":"failed"}',
            $signingInput
        );

        // The nonce and reportedAt must follow the JSON block, separated by newlines.
        $parts = explode("\n", $signingInput);
        $this->assertCount(3, $parts);
        $this->assertSame('nonce-abc', $parts[1]);
        $this->assertSame('2024-06-01T12:00:00Z', $parts[2]);
    }

    // =========================================================================
    // Private helper — signs with the test private key
    // =========================================================================

    private function sign(string $input): string
    {
        $privateKey = openssl_pkey_get_private(self::TEST_PRIVATE_KEY_PEM);
        openssl_sign($input, $derSignature, $privateKey, OPENSSL_ALGO_SHA256);
        return rtrim(strtr(base64_encode($derSignature), '+/', '-_'), '=');
    }
}
