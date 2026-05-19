<?php

namespace App\Services;

use Illuminate\Contracts\Encryption\DecryptException;

/**
 * AES-256-GCM payload encryption service (Axiom 5 — Zero-Trust Payload Encryption).
 *
 * Every data exchange between external systems and this gateway is encrypted at the
 * payload level so that even TLS termination or proxy log interception cannot expose
 * sensitive data such as phone numbers, OTP codes, or login contexts.
 *
 * Wire format (all values base64-encoded):
 *   {
 *     "encrypted_payload": "<base64>",
 *     "iv":               "<base64>",
 *     "tag":              "<base64>"
 *   }
 *
 * Cipher: aes-256-gcm (hardcoded — never changed by caller).
 * Key format: base64-encoded 32-byte raw key (256 bits).
 */
class PayloadEncryptionService
{
    private const CIPHER = 'aes-256-gcm';
    private const TAG_LENGTH = 16;

    /**
     * Encrypt a data array and return the wire envelope.
     *
     * @param  array  $data  Arbitrary key→value map to encrypt.
     * @param  string $key   Base64-encoded 32-byte AES-256 key.
     * @return array{encrypted_payload: string, iv: string, tag: string}
     */
    public function encrypt(array $data, string $key): array
    {
        $rawKey    = base64_decode($key, true);
        $ivLength  = openssl_cipher_iv_length(self::CIPHER);
        $iv        = random_bytes($ivLength);
        $tag       = '';

        $ciphertext = openssl_encrypt(
            json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            self::CIPHER,
            $rawKey,
            OPENSSL_RAW_DATA,
            $iv,
            $tag,
            '',
            self::TAG_LENGTH,
        );

        if ($ciphertext === false) {
            throw new \RuntimeException('AES-256-GCM encryption failed.');
        }

        return [
            'encrypted_payload' => base64_encode($ciphertext),
            'iv'                => base64_encode($iv),
            'tag'               => base64_encode($tag),
        ];
    }

    /**
     * Decrypt and authenticate a wire envelope, returning the original data array.
     *
     * @param  string $encryptedPayload  Base64-encoded ciphertext.
     * @param  string $key               Base64-encoded 32-byte AES-256 key.
     * @param  string $iv                Base64-encoded IV.
     * @param  string $tag               Base64-encoded GCM authentication tag.
     * @return array                     The decrypted JSON decoded to an array.
     *
     * @throws DecryptException if authentication tag verification fails or decryption errors.
     */
    public function decrypt(
        string $encryptedPayload,
        string $key,
        string $iv,
        string $tag,
    ): array {
        $rawKey        = base64_decode($key, true);
        $rawIv         = base64_decode($iv, true);
        $rawTag        = base64_decode($tag, true);
        $rawCiphertext = base64_decode($encryptedPayload, true);

        if ($rawKey === false || $rawIv === false || $rawTag === false || $rawCiphertext === false) {
            throw new DecryptException('Malformed base64 in encrypted envelope.');
        }

        $plaintext = openssl_decrypt(
            $rawCiphertext,
            self::CIPHER,
            $rawKey,
            OPENSSL_RAW_DATA,
            $rawIv,
            $rawTag,
        );

        if ($plaintext === false) {
            // GCM authentication tag mismatch — ciphertext has been tampered with.
            throw new DecryptException('AES-256-GCM authentication tag verification failed.');
        }

        $decoded = json_decode($plaintext, true);

        if (!is_array($decoded)) {
            throw new DecryptException('Decrypted payload is not valid JSON.');
        }

        return $decoded;
    }
}
