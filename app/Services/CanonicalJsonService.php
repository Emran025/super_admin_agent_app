<?php

namespace App\Services;

/**
 * Canonical JSON serialization — mirrors CanonicalJson.encode() from the Flutter agent.
 *
 * Contract (must match Dart's jsonEncode output after alphabetical key sort):
 * - All map keys sorted alphabetically at every nesting level.
 * - No pretty-printing, no trailing whitespace.
 * - UTF-8 encoding, no Unicode escape sequences for non-ASCII chars.
 * - No trailing slash escaping (JSON_UNESCAPED_SLASHES).
 *
 * Any deviation from this contract will produce a signing input that does not match
 * what the mobile agent signed — causing all signature verifications to fail.
 */
class CanonicalJsonService
{
    /**
     * Encodes $data as canonical JSON with all keys sorted alphabetically.
     * Equivalent to the Flutter agent's CanonicalJson.encode().
     */
    public static function encode(array $data): string
    {
        ksort($data);

        foreach ($data as &$value) {
            if (is_array($value)) {
                $value = json_decode(self::encode($value), true, flags: JSON_THROW_ON_ERROR);
            }
        }

        return json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
    }
}
