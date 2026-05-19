<?php

namespace Tests\Feature;

use App\Events\AgentCommandDispatched;
use App\Events\TwoFactorChallengeIssued;
use App\Models\Agent;
use App\Models\ExternalSystem;
use App\Services\PayloadEncryptionService;
use Database\Factories\ExternalSystemFactory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * ExternalSystemApiTest — Phase 11 verification suite.
 *
 * Proves the External Systems API Gateway enforces:
 *   1. Successful decryption & authenticated OTP request → 202, DB record, event broadcast.
 *   2. Tampered ciphertext / tag → 400, no DB side-effects.
 *   3. Capability authorization block → 403.
 *   4. Sandbox protection gate → sandbox_log flag set on DB records (appropriate separation).
 *
 * All tests use Event::fake() so Reverb is not required during CI.
 */
class ExternalSystemApiTest extends TestCase
{
    use RefreshDatabase;

    private PayloadEncryptionService $encryptionService;

    protected function setUp(): void
    {
        parent::setUp();
        $this->encryptionService = new PayloadEncryptionService();
    }

    // =========================================================================
    // Helper: create an ExternalSystem with plaintext credentials attached.
    // =========================================================================

    /**
     * Creates an ExternalSystem and returns [$system, $plainToken, $plainKey].
     * This is the canonical way to get credentials for test HTTP headers.
     */
    private function makeSystem(array $overrides = []): array
    {
        /** @var ExternalSystemFactory $factory */
        $factory = ExternalSystem::factory();

        $plainToken = Str::random(64);
        $rawKey     = random_bytes(32);
        $plainKey   = base64_encode($rawKey);

        $system = $factory->state(array_merge([
            'api_token_hash' => hash('sha256', $plainToken),
            'encryption_key' => Crypt::encryptString($plainKey),
        ], $overrides))->create();

        return [$system, $plainToken, $plainKey];
    }

    /**
     * Creates a paired agent so controllers can find one to broadcast to.
     */
    private function makeAgent(array $overrides = []): Agent
    {
        return Agent::factory()->create(array_merge([
            'capabilities' => ['otp_gateway', 'two_fa'],
        ], $overrides));
    }

    // =========================================================================
    // Test 1 — Successful decryption & authenticated OTP request
    // =========================================================================

    #[Test]
    public function valid_encrypted_otp_request_returns_202_and_stores_record(): void
    {
        Event::fake([AgentCommandDispatched::class]);

        $this->makeAgent();
        [$system, $plainToken, $plainKey] = $this->makeSystem([
            'capabilities' => ['otp'],
            'is_test'      => false,
        ]);

        $payload  = ['phone_number' => '+1234567890', 'message_body' => 'Your code is 654321'];
        $envelope = $this->encryptionService->encrypt($payload, $plainKey);

        $response = $this->postJson('/api/v1/external/otp', $envelope, [
            'Authorization' => "Bearer {$plainToken}",
        ]);

        $response->assertStatus(202)
                 ->assertJsonStructure(['command_id']);

        $commandId = $response->json('command_id');

        $this->assertDatabaseHas('otp_dispatches', [
            'id'                 => $commandId,
            'external_system_id' => $system->id,
            'phone_number'       => '+1234567890',
            'status'             => 'dispatched',
            'sandbox_log'        => false,
        ]);

        Event::assertDispatched(AgentCommandDispatched::class, function ($event) {
            return $event->recipientPhoneNumber === '+1234567890'
                && $event->messageBody === 'Your code is 654321';
        });
    }

    // =========================================================================
    // Test 2 — Tampered ciphertext must return 400 with no DB side-effects
    // =========================================================================

    #[Test]
    public function tampered_ciphertext_returns_400_and_no_db_record(): void
    {
        Event::fake([AgentCommandDispatched::class]);

        $this->makeAgent();
        [$system, $plainToken, $plainKey] = $this->makeSystem([
            'capabilities' => ['otp'],
        ]);

        $payload  = ['phone_number' => '+1234567890', 'message_body' => 'Your code is 123456'];
        $envelope = $this->encryptionService->encrypt($payload, $plainKey);

        // Corrupt the last byte of the ciphertext (simulates tampering).
        $cipherBytes = base64_decode($envelope['encrypted_payload']);
        $cipherBytes[strlen($cipherBytes) - 1] = chr(ord($cipherBytes[strlen($cipherBytes) - 1]) ^ 0xFF);
        $envelope['encrypted_payload'] = base64_encode($cipherBytes);

        $response = $this->postJson('/api/v1/external/otp', $envelope, [
            'Authorization' => "Bearer {$plainToken}",
        ]);

        $response->assertStatus(400);

        $this->assertDatabaseMissing('otp_dispatches', [
            'external_system_id' => $system->id,
        ]);

        Event::assertNotDispatched(AgentCommandDispatched::class);
    }

    #[Test]
    public function tampered_auth_tag_returns_400(): void
    {
        Event::fake([AgentCommandDispatched::class]);

        $this->makeAgent();
        [$system, $plainToken, $plainKey] = $this->makeSystem([
            'capabilities' => ['otp'],
        ]);

        $payload  = ['phone_number' => '+9876543210', 'message_body' => 'Test Code'];
        $envelope = $this->encryptionService->encrypt($payload, $plainKey);

        // Corrupt the authentication tag.
        $tagBytes = base64_decode($envelope['tag']);
        $tagBytes[0] = chr(ord($tagBytes[0]) ^ 0xFF);
        $envelope['tag'] = base64_encode($tagBytes);

        $response = $this->postJson('/api/v1/external/otp', $envelope, [
            'Authorization' => "Bearer {$plainToken}",
        ]);

        $response->assertStatus(400);

        $this->assertDatabaseMissing('otp_dispatches', [
            'external_system_id' => $system->id,
        ]);

        Event::assertNotDispatched(AgentCommandDispatched::class);
    }

    // =========================================================================
    // Test 3 — Capability authorization block
    // =========================================================================

    #[Test]
    public function system_without_otp_capability_receives_403(): void
    {
        Event::fake([AgentCommandDispatched::class]);

        $this->makeAgent();
        [$system, $plainToken, $plainKey] = $this->makeSystem([
            'capabilities' => ['super_admin_login'],  // no 'otp'
        ]);

        $payload  = ['phone_number' => '+1234567890', 'message_body' => 'Code 999999'];
        $envelope = $this->encryptionService->encrypt($payload, $plainKey);

        $response = $this->postJson('/api/v1/external/otp', $envelope, [
            'Authorization' => "Bearer {$plainToken}",
        ]);

        $response->assertStatus(403);

        $this->assertDatabaseMissing('otp_dispatches', [
            'external_system_id' => $system->id,
        ]);

        Event::assertNotDispatched(AgentCommandDispatched::class);
    }

    #[Test]
    public function system_without_super_admin_login_capability_receives_403_on_login(): void
    {
        Event::fake([TwoFactorChallengeIssued::class]);

        $this->makeAgent();
        [$system, $plainToken, $plainKey] = $this->makeSystem([
            'capabilities' => ['otp'],  // no 'super_admin_login'
        ]);

        $payload  = ['username' => 'admin', 'context_label' => 'Chrome / Linux'];
        $envelope = $this->encryptionService->encrypt($payload, $plainKey);

        $response = $this->postJson('/api/v1/external/login', $envelope, [
            'Authorization' => "Bearer {$plainToken}",
        ]);

        $response->assertStatus(403);

        $this->assertDatabaseMissing('two_factor_challenges', [
            'external_system_id' => $system->id,
        ]);

        Event::assertNotDispatched(TwoFactorChallengeIssued::class);
    }

    // =========================================================================
    // Test 4 — Sandbox protection gate
    // =========================================================================

    #[Test]
    public function test_system_requests_are_flagged_as_sandbox_log(): void
    {
        Event::fake([AgentCommandDispatched::class]);

        $this->makeAgent();
        [$system, $plainToken, $plainKey] = $this->makeSystem([
            'capabilities' => ['otp'],
            'is_test'      => true,
        ]);

        $payload  = ['phone_number' => '+1111111111', 'message_body' => 'Sandbox code 000000'];
        $envelope = $this->encryptionService->encrypt($payload, $plainKey);

        $response = $this->postJson('/api/v1/external/otp', $envelope, [
            'Authorization' => "Bearer {$plainToken}",
        ]);

        $response->assertStatus(202);

        $commandId = $response->json('command_id');

        // Sandbox separation: dispatch record must be flagged with sandbox_log = true.
        $this->assertDatabaseHas('otp_dispatches', [
            'id'                 => $commandId,
            'external_system_id' => $system->id,
            'sandbox_log'        => true,
        ]);
    }

    #[Test]
    public function test_system_is_rejected_in_production_environment(): void
    {
        Event::fake([AgentCommandDispatched::class]);

        $this->makeAgent();
        [$system, $plainToken, $plainKey] = $this->makeSystem([
            'capabilities' => ['otp'],
            'is_test'      => true,
        ]);

        // Temporarily simulate a production environment.
        app()->detectEnvironment(fn () => 'production');

        $payload  = ['phone_number' => '+2222222222', 'message_body' => 'Should be blocked'];
        $envelope = $this->encryptionService->encrypt($payload, $plainKey);

        $response = $this->postJson('/api/v1/external/otp', $envelope, [
            'Authorization' => "Bearer {$plainToken}",
        ]);

        $response->assertStatus(403)
                 ->assertJsonFragment(['error' => 'Test systems are not permitted in production.']);

        $this->assertDatabaseMissing('otp_dispatches', [
            'external_system_id' => $system->id,
        ]);

        Event::assertNotDispatched(AgentCommandDispatched::class);

        // Restore test environment.
        app()->detectEnvironment(fn () => 'testing');
    }

    // =========================================================================
    // Test 5 — Unknown / invalid bearer token returns 401
    // =========================================================================

    #[Test]
    public function unknown_token_returns_401(): void
    {
        Event::fake([AgentCommandDispatched::class]);

        $this->makeAgent();
        [$system, $plainToken, $plainKey] = $this->makeSystem(['capabilities' => ['otp']]);

        $payload  = ['phone_number' => '+0000000000', 'message_body' => 'Test'];
        $envelope = $this->encryptionService->encrypt($payload, $plainKey);

        $response = $this->postJson('/api/v1/external/otp', $envelope, [
            'Authorization' => 'Bearer invalid-token-that-does-not-exist',
        ]);

        $response->assertStatus(401);

        Event::assertNotDispatched(AgentCommandDispatched::class);
    }

    // =========================================================================
    // Test 6 — Successful 2FA login challenge
    // =========================================================================

    #[Test]
    public function valid_encrypted_login_request_returns_202_and_stores_challenge(): void
    {
        Event::fake([TwoFactorChallengeIssued::class]);

        $this->makeAgent();
        [$system, $plainToken, $plainKey] = $this->makeSystem([
            'capabilities' => ['super_admin_login'],
            'is_test'      => false,
        ]);

        $payload  = ['username' => 'admin', 'context_label' => 'Login from Chrome / Linux'];
        $envelope = $this->encryptionService->encrypt($payload, $plainKey);

        $response = $this->postJson('/api/v1/external/login', $envelope, [
            'Authorization' => "Bearer {$plainToken}",
        ]);

        $response->assertStatus(202)
                 ->assertJsonStructure(['challenge_id']);

        $challengeId = $response->json('challenge_id');

        $this->assertDatabaseHas('two_factor_challenges', [
            'id'                 => $challengeId,
            'external_system_id' => $system->id,
            'status'             => 'pending',
            'sandbox_log'        => false,
        ]);

        Event::assertDispatched(TwoFactorChallengeIssued::class);
    }
}
