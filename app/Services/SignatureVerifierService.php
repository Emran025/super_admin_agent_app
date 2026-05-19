<?php

namespace App\Services;

/**
 * Verifies ECDSA-SHA256 (P-256) signatures produced by the mobile agent.
 *
 * The mobile agent signs using pointycastle (EC prime256v1, SHA-256/ECDSA).
 * Its public key is a base64url-encoded 65-byte uncompressed EC point (04||X||Y).
 * Its signatures are DER-encoded ECDSA (r, s) pairs, base64url-encoded without padding.
 *
 * Verification uses PHP's built-in openssl extension — no external library required.
 * The raw EC point is wrapped in a SubjectPublicKeyInfo DER structure so openssl can
 * parse it natively.
 *
 * NOTE: The spec document (Phase 8) references ED25519. This implementation uses
 * ECDSA-SHA256 P-256 because that is what the established Flutter agent produces
 * (AndroidKeystoreSigningService / pointycastle prime256v1). The Agent file is the
 * single source of truth per the project mandate.
 */
class SignatureVerifierService
{
    /**
     * SubjectPublicKeyInfo DER header for an EC P-256 (prime256v1) uncompressed public key.
     *
     * Breakdown:
     *   30 59          — SEQUENCE (89 total bytes follow)
     *     30 13        — SEQUENCE (algorithm identifier, 19 bytes)
     *       06 07 2a 86 48 ce 3d 02 01  — OID id-ecPublicKey (1.2.840.10045.2.1)
     *       06 08 2a 86 48 ce 3d 03 01 07  — OID prime256v1 (1.2.840.10045.3.1.7)
     *     03 42 00     — BIT STRING (66 bytes: 1 unused-bits byte + 65-byte EC point)
     *
     * This 26-byte header is prepended to the raw 65-byte uncompressed point to form
     * a valid 91-byte SubjectPublicKeyInfo DER, which openssl_pkey_get_public() accepts.
     */
    private const P256_SPKI_HEADER_HEX = '3059301306072a8648ce3d020106082a8648ce3d030107034200';

    /**
     * Verifies that $base64urlSignature was produced by the agent whose public key is
     * $base64urlPublicKey over the signing input $signingInput.
     *
     * Returns true only when ALL of the following hold:
     *   1. $base64urlPublicKey decodes to exactly 65 bytes starting with 0x04.
     *   2. $base64urlSignature decodes to a valid DER-encoded ECDSA signature.
     *   3. openssl_verify returns 1 (verified) — not 0 (failed) or -1 (error).
     */
    public function verify(
        string $signingInput,
        string $base64urlSignature,
        string $base64urlPublicKey
    ): bool {
        $rawPoint = $this->base64UrlDecode($base64urlPublicKey);

        if ($rawPoint === false || strlen($rawPoint) !== 65 || ord($rawPoint[0]) !== 0x04) {
            return false;
        }

        $derSignature = $this->base64UrlDecode($base64urlSignature);
        if ($derSignature === false || strlen($derSignature) === 0) {
            return false;
        }

        $pem = $this->buildPem($rawPoint);
        $publicKey = openssl_pkey_get_public($pem);
        if ($publicKey === false) {
            return false;
        }

        $result = openssl_verify($signingInput, $derSignature, $publicKey, OPENSSL_ALGO_SHA256);

        return $result === 1;
    }

    /**
     * Reconstructs the signing input from the OTP delivery report body fields.
     *
     * Matches exactly what ExecuteSmsDispatchUseCase builds on the Flutter side:
     *   CanonicalJson.encode({command_id, nonce, reported_at, status})
     *   + "\n" + nonce + "\n" + reported_at
     *
     * Keys are sorted alphabetically by CanonicalJsonService::encode().
     */
    public function buildOtpReportSigningInput(
        string $commandId,
        string $nonce,
        string $reportedAt,
        string $status
    ): string {
        $canonicalJson = CanonicalJsonService::encode([
            'command_id'  => $commandId,
            'nonce'       => $nonce,
            'reported_at' => $reportedAt,
            'status'      => $status,
        ]);

        return $canonicalJson . "\n" . $nonce . "\n" . $reportedAt;
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    private function buildPem(string $rawPoint): string
    {
        $header = hex2bin(self::P256_SPKI_HEADER_HEX);
        $der = $header . $rawPoint;
        $b64 = base64_encode($der);

        return "-----BEGIN PUBLIC KEY-----\n"
            . chunk_split($b64, 64, "\n")
            . "-----END PUBLIC KEY-----\n";
    }

    private function base64UrlDecode(string $input): string|false
    {
        $base64 = strtr($input, '-_', '+/');
        $padding = (4 - strlen($base64) % 4) % 4;
        $padded = $base64 . str_repeat('=', $padding);

        return base64_decode($padded, true);
    }
}
