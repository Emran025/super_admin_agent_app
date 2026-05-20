<?php

namespace Tests\Feature;

use App\Models\Agent;
use App\Models\ExternalSystem;
use App\Services\CanonicalJsonService;
use Database\Factories\AgentFactory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class AgentSystemLinkTest extends TestCase
{
    use RefreshDatabase;

    private const TEST_PRIVATE_KEY_PEM = <<<'PEM'
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgX/cu2y+Wv0dMTnr1
KQ3m2jM2ydpLp6hEu29EEztinr2hRANCAASdiK/0iuyyXL/aMkfEgLuR5YkZ182d
C+ExC2jBJZOvvAj4qJZqrva2vMNSPwgAi+s4fnHI2d6e4sWo690sVM/W
-----END PRIVATE KEY-----
PEM;

    private Agent $agent;
    private ExternalSystem $externalSystem;

    protected function setUp(): void
    {
        parent::setUp();

        $this->agent = Agent::factory()->create();
        $this->externalSystem = ExternalSystem::create([
            'id' => (string) Str::uuid(),
            'name' => 'Test External System',
            'api_token_hash' => hash('sha256', 'test-token'),
            'encryption_key' => 'encrypted-key',
            'capabilities' => ['otp', 'super_admin_login'],
            'is_test' => true,
        ]);
    }

    #[Test]
    public function link_system_with_valid_signature_is_accepted(): void
    {
        $nonce = bin2hex(random_bytes(16));
        $timestamp = now()->toIso8601String();

        $canonicalBody = CanonicalJsonService::encode([
            'system_id' => $this->externalSystem->id,
        ]);
        $signingInput = $canonicalBody . "\n" . $nonce . "\n" . $timestamp;

        $privateKey = openssl_pkey_get_private(self::TEST_PRIVATE_KEY_PEM);
        openssl_sign($signingInput, $derSignature, $privateKey, OPENSSL_ALGO_SHA256);
        $signature = rtrim(strtr(base64_encode($derSignature), '+/', '-_'), '=');

        $response = $this->withHeaders([
            'X-Agent-Public-Key-Id' => $this->agent->public_key_id,
            'X-Agent-Nonce' => $nonce,
            'X-Agent-Timestamp' => $timestamp,
            'X-Agent-Signature' => $signature,
        ])->postJson('/api/v1/agent/link-system', [
            'system_id' => $this->externalSystem->id,
        ]);

        $response->assertStatus(200)
                 ->assertJson([
                     'success' => true,
                     'system' => [
                         'id' => $this->externalSystem->id,
                         'name' => 'Test External System',
                         'is_test' => true,
                     ]
                 ]);

        $this->assertDatabaseHas('external_systems', [
            'id' => $this->externalSystem->id,
            'agent_id' => $this->agent->agent_id,
        ]);

        $this->assertDatabaseHas('used_nonces', [
            'agent_id' => $this->agent->agent_id,
            'nonce' => $nonce,
        ]);
    }

    #[Test]
    public function link_system_with_invalid_signature_is_rejected(): void
    {
        $nonce = bin2hex(random_bytes(16));
        $timestamp = now()->toIso8601String();

        $response = $this->withHeaders([
            'X-Agent-Public-Key-Id' => $this->agent->public_key_id,
            'X-Agent-Nonce' => $nonce,
            'X-Agent-Timestamp' => $timestamp,
            'X-Agent-Signature' => 'invalid-signature-value',
        ])->postJson('/api/v1/agent/link-system', [
            'system_id' => $this->externalSystem->id,
        ]);

        $response->assertStatus(403)
                 ->assertJson(['error' => 'Invalid signature.']);
    }

    #[Test]
    public function link_system_with_replayed_nonce_is_rejected(): void
    {
        $nonce = bin2hex(random_bytes(16));
        $timestamp = now()->toIso8601String();

        $canonicalBody = CanonicalJsonService::encode([
            'system_id' => $this->externalSystem->id,
        ]);
        $signingInput = $canonicalBody . "\n" . $nonce . "\n" . $timestamp;

        $privateKey = openssl_pkey_get_private(self::TEST_PRIVATE_KEY_PEM);
        openssl_sign($signingInput, $derSignature, $privateKey, OPENSSL_ALGO_SHA256);
        $signature = rtrim(strtr(base64_encode($derSignature), '+/', '-_'), '=');

        // Insert nonce to database to simulate replay
        \App\Models\UsedNonce::create([
            'agent_id' => $this->agent->agent_id,
            'nonce' => $nonce,
            'used_at' => now(),
        ]);

        $response = $this->withHeaders([
            'X-Agent-Public-Key-Id' => $this->agent->public_key_id,
            'X-Agent-Nonce' => $nonce,
            'X-Agent-Timestamp' => $timestamp,
            'X-Agent-Signature' => $signature,
        ])->postJson('/api/v1/agent/link-system', [
            'system_id' => $this->externalSystem->id,
        ]);

        $response->assertStatus(409)
                 ->assertJson(['error' => 'Nonce already used.']);
    }

    #[Test]
    public function get_linked_systems_returns_correct_list(): void
    {
        $this->externalSystem->update(['agent_id' => $this->agent->agent_id]);

        $nonce = bin2hex(random_bytes(16));
        $timestamp = now()->toIso8601String();

        // GET request signing input (empty canonical body)
        $signingInput = "" . "\n" . $nonce . "\n" . $timestamp;

        $privateKey = openssl_pkey_get_private(self::TEST_PRIVATE_KEY_PEM);
        openssl_sign($signingInput, $derSignature, $privateKey, OPENSSL_ALGO_SHA256);
        $signature = rtrim(strtr(base64_encode($derSignature), '+/', '-_'), '=');

        $response = $this->withHeaders([
            'X-Agent-Public-Key-Id' => $this->agent->public_key_id,
            'X-Agent-Nonce' => $nonce,
            'X-Agent-Timestamp' => $timestamp,
            'X-Agent-Signature' => $signature,
        ])->getJson('/api/v1/agent/linked-systems');

        $response->assertStatus(200)
                 ->assertJsonCount(1, 'systems')
                 ->assertJsonFragment([
                     'id' => $this->externalSystem->id,
                     'name' => 'Test External System',
                 ]);
    }

    #[Test]
    public function unlink_system_removes_association(): void
    {
        $this->externalSystem->update(['agent_id' => $this->agent->agent_id]);

        $nonce = bin2hex(random_bytes(16));
        $timestamp = now()->toIso8601String();

        $canonicalBody = CanonicalJsonService::encode([
            'system_id' => $this->externalSystem->id,
        ]);
        $signingInput = $canonicalBody . "\n" . $nonce . "\n" . $timestamp;

        $privateKey = openssl_pkey_get_private(self::TEST_PRIVATE_KEY_PEM);
        openssl_sign($signingInput, $derSignature, $privateKey, OPENSSL_ALGO_SHA256);
        $signature = rtrim(strtr(base64_encode($derSignature), '+/', '-_'), '=');

        $response = $this->withHeaders([
            'X-Agent-Public-Key-Id' => $this->agent->public_key_id,
            'X-Agent-Nonce' => $nonce,
            'X-Agent-Timestamp' => $timestamp,
            'X-Agent-Signature' => $signature,
        ])->postJson('/api/v1/agent/unlink-system', [
            'system_id' => $this->externalSystem->id,
        ]);

        $response->assertStatus(200)
                 ->assertJson(['success' => true]);

        $this->assertDatabaseHas('external_systems', [
            'id' => $this->externalSystem->id,
            'agent_id' => null,
        ]);
    }
}
