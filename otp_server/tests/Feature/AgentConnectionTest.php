<?php

namespace Tests\Feature;

use App\Models\Agent;
use App\Models\ExternalSystem;
use App\Models\OtpDispatch;
use App\Models\TwoFactorChallenge;
use App\Services\CanonicalJsonService;
use Database\Factories\AgentFactory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class AgentConnectionTest extends TestCase
{
    use RefreshDatabase;

    private const TEST_PRIVATE_KEY_PEM = <<<'PEM'
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgX/cu2y+Wv0dMTnr1
KQ3m2jM2ydpLp6hEu29EEztinr2hRANCAASdiK/0iuyyXL/aMkfEgLuR5YkZ182d
C+ExC2jBJZOvvAj4qJZqrva2vMNSPwgAi+s4fnHI2d6e4sWo690sVM/W
-----END PRIVATE KEY-----
PEM;

    #[Test]
    public function agent_is_online_based_on_last_seen_at()
    {
        $agent = Agent::factory()->create(['last_seen_at' => null]);
        $this->assertFalse($agent->isOnline());

        $agent->update(['last_seen_at' => now()->subSeconds(30)]);
        $this->assertTrue($agent->isOnline());

        $agent->update(['last_seen_at' => now()->subMinutes(3)]);
        $this->assertFalse($agent->isOnline());
    }

    #[Test]
    public function last_seen_at_is_updated_on_agent_reporting()
    {
        $agent = Agent::factory()->create(['last_seen_at' => null]);
        $dispatch = OtpDispatch::factory()->dispatched()->create();

        $payload = [
            'command_id'          => $dispatch->id,
            'status'              => 'delivered',
            'reported_at'         => now()->toIso8601String(),
            'nonce'               => bin2hex(random_bytes(16)),
            'agent_public_key_id' => AgentFactory::TEST_PUBLIC_KEY_ID,
            'signature'           => '',
        ];

        $canonicalJson = CanonicalJsonService::encode([
            'command_id'  => $payload['command_id'],
            'nonce'       => $payload['nonce'],
            'reported_at' => $payload['reported_at'],
            'status'      => $payload['status'],
        ]);

        $signingInput = $canonicalJson . "\n" . $payload['nonce'] . "\n" . $payload['reported_at'];
        $privateKey = openssl_pkey_get_private(self::TEST_PRIVATE_KEY_PEM);
        openssl_sign($signingInput, $derSignature, $privateKey, OPENSSL_ALGO_SHA256);
        $payload['signature'] = rtrim(strtr(base64_encode($derSignature), '+/', '-_'), '=');

        $this->postJson("/api/v1/otp-commands/{$dispatch->id}/report", $payload)
             ->assertStatus(200);

        $agent->refresh();
        $this->assertNotNull($agent->last_seen_at);
        $this->assertTrue($agent->last_seen_at->isAfter(now()->subSeconds(5)));
    }

    #[Test]
    public function last_seen_at_is_updated_on_agent_broadcasting_auth()
    {
        $agent = Agent::factory()->create(['last_seen_at' => null]);

        $socketId = '1234.5678';
        $channelName = 'private-agent.' . $agent->system_id;
        $nonce = bin2hex(random_bytes(16));
        $timestamp = (string) time();

        $canonicalBody = CanonicalJsonService::encode([
            'channel_name' => $channelName,
            'socket_id'    => $socketId,
        ]);
        $signingInput = $canonicalBody . "\n" . $nonce . "\n" . $timestamp;

        $privateKey = openssl_pkey_get_private(self::TEST_PRIVATE_KEY_PEM);
        openssl_sign($signingInput, $derSignature, $privateKey, OPENSSL_ALGO_SHA256);
        $signature = rtrim(strtr(base64_encode($derSignature), '+/', '-_'), '=');

        $response = $this->postJson('/api/v1/broadcasting/auth', [
            'socket_id' => $socketId,
            'channel_name' => $channelName,
        ], [
            'X-Agent-Public-Key-Id' => AgentFactory::TEST_PUBLIC_KEY_ID,
            'X-Agent-Nonce' => $nonce,
            'X-Agent-Timestamp' => $timestamp,
            'X-Agent-Signature' => $signature,
        ]);

        $response->assertStatus(200);

        $agent->refresh();
        $this->assertNotNull($agent->last_seen_at);
        $this->assertTrue($agent->last_seen_at->isAfter(now()->subSeconds(5)));
    }

    #[Test]
    public function external_system_pairing_stores_encrypted_test_token()
    {
        $response = $this->post('/testbed/system-pairing', [
            'name' => 'My Test System',
            'capabilities' => ['otp', 'super_admin_login'],
        ]);

        $response->assertStatus(200);

        $system = ExternalSystem::where('name', 'My Test System')->first();
        $this->assertNotNull($system);
        $this->assertTrue($system->is_test);
        $this->assertNotNull($system->test_token_encrypted);

        $decryptedToken = Crypt::decryptString($system->test_token_encrypted);
        $this->assertEquals(hash('sha256', $decryptedToken), $system->api_token_hash);
    }
}
