<?php

namespace Tests\Unit;

use App\Services\CanonicalJsonService;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * CanonicalJsonServiceTest
 *
 * Verifies that CanonicalJsonService::encode() produces output that exactly
 * matches what the Flutter agent's CanonicalJson.encode() would produce.
 *
 * Any deviation breaks the signing contract between server and agent:
 *   - Different key order → different signing input → all signatures fail.
 *   - Escaped Unicode / slashes → mismatch with Dart's jsonEncode defaults.
 *   - Pretty-printing / trailing whitespace → signing input mismatch.
 */
class CanonicalJsonServiceTest extends TestCase
{
    // =========================================================================
    // Test 1 — Keys are sorted alphabetically
    // =========================================================================

    #[Test]
    public function keys_are_sorted_alphabetically(): void
    {
        $result = CanonicalJsonService::encode([
            'z_last'  => 'z',
            'a_first' => 'a',
            'm_mid'   => 'm',
        ]);

        $this->assertSame('{"a_first":"a","m_mid":"m","z_last":"z"}', $result);
    }

    // =========================================================================
    // Test 2 — Nested maps have keys sorted at every level
    // =========================================================================

    #[Test]
    public function nested_map_keys_are_sorted(): void
    {
        $result = CanonicalJsonService::encode([
            'outer_b' => ['inner_z' => 1, 'inner_a' => 2],
            'outer_a' => 'simple',
        ]);

        $this->assertSame('{"outer_a":"simple","outer_b":{"inner_a":2,"inner_z":1}}', $result);
    }

    // =========================================================================
    // Test 3 — No extra whitespace
    // =========================================================================

    #[Test]
    public function output_has_no_whitespace(): void
    {
        $result = CanonicalJsonService::encode([
            'b' => 'beta',
            'a' => 'alpha',
        ]);

        $this->assertStringNotContainsString(' ', $result);
        $this->assertStringNotContainsString("\n", $result);
        $this->assertStringNotContainsString("\t", $result);
    }

    // =========================================================================
    // Test 4 — Slashes are NOT escaped (must match Dart's jsonEncode)
    // =========================================================================

    #[Test]
    public function slashes_are_not_escaped(): void
    {
        $result = CanonicalJsonService::encode([
            'url' => 'https://example.com/api/v1',
        ]);

        // Dart's jsonEncode does not escape forward slashes.
        $this->assertStringContainsString('https://example.com/api/v1', $result);
        $this->assertStringNotContainsString('https:\/\/', $result);
    }

    // =========================================================================
    // Test 5 — OTP report signing input (matches AgentReportController)
    // =========================================================================

    #[Test]
    public function otp_report_signing_input_is_correctly_formed(): void
    {
        $commandId  = 'abc-123';
        $nonce      = 'deadbeef';
        $reportedAt = '2024-01-01T00:00:00.000Z';
        $status     = 'delivered';

        $canonical = CanonicalJsonService::encode([
            'command_id'  => $commandId,
            'nonce'       => $nonce,
            'reported_at' => $reportedAt,
            'status'      => $status,
        ]);

        // Keys sorted: command_id, nonce, reported_at, status
        $expected = '{"command_id":"abc-123","nonce":"deadbeef","reported_at":"2024-01-01T00:00:00.000Z","status":"delivered"}';
        $this->assertSame($expected, $canonical);

        // Full signing input format
        $signingInput = $canonical . "\n" . $nonce . "\n" . $reportedAt;
        $this->assertStringContainsString("\ndeadbeef\n", $signingInput);
    }

    // =========================================================================
    // Test 6 — Empty array produces {}
    // =========================================================================

    #[Test]
    public function empty_array_produces_empty_object(): void
    {
        $result = CanonicalJsonService::encode([]);
        $this->assertSame('{}', $result);
    }

    // =========================================================================
    // Test 7 — Integer and boolean values are preserved
    // =========================================================================

    #[Test]
    public function integer_and_boolean_values_are_preserved(): void
    {
        $result = CanonicalJsonService::encode([
            'count' => 42,
            'flag'  => true,
            'name'  => 'test',
        ]);

        $this->assertSame('{"count":42,"flag":true,"name":"test"}', $result);
    }
}
