<?php

namespace App\Console\Commands;

use App\Models\Agent;
use Illuminate\Console\Command;
use Illuminate\Support\Str;

/**
 * Artisan command to manually register (or re-register) a paired agent record.
 *
 * Usage:
 *   php artisan agent:register
 *     --system-id=<uuid>          (optional — auto-generated if omitted)
 *     --agent-id=<uuid>           (optional — auto-generated if omitted)
 *     --public-key=<base64url>    (required — 65-byte uncompressed P-256 EC point)
 *     --public-key-id=<uuid>      (required — matches the agent's Keystore alias)
 *     --fcm-token=<token>         (required — the agent's current FCM registration token)
 *     --capabilities=<csv>        (optional — comma-separated; default: otp_gateway)
 *
 * This command is primarily used in development/testbed environments to seed an agent
 * record without going through the full pairing ceremony. In production, pairing is
 * done via POST /v1/pair.
 */
class AgentRegisterCommand extends Command
{
    protected $signature = 'agent:register
                            {--system-id= : The system UUID (auto-generated if omitted)}
                            {--agent-id= : The agent UUID (auto-generated if omitted)}
                            {--public-key= : Base64url-encoded 65-byte uncompressed P-256 EC point (REQUIRED)}
                            {--public-key-id= : UUID key alias from the Android Keystore (REQUIRED)}
                            {--fcm-token= : FCM registration token for this agent (REQUIRED)}
                            {--capabilities= : Comma-separated capability list (default: otp_gateway)}';

    protected $description = 'Register or update a paired mobile agent record in the database.';

    public function handle(): int
    {
        $publicKey   = $this->option('public-key');
        $publicKeyId = $this->option('public-key-id');
        $fcmToken    = $this->option('fcm-token');

        if (!$publicKey || !$publicKeyId || !$fcmToken) {
            $this->error('--public-key, --public-key-id, and --fcm-token are all required.');
            return self::FAILURE;
        }

        $rawPoint = base64_decode(strtr(str_pad(
            strtr($publicKey, '-_', '+/'),
            strlen($publicKey) + (4 - strlen($publicKey) % 4) % 4,
            '='
        ), '+/', '+/'), true);

        if ($rawPoint === false || strlen($rawPoint) !== 65 || ord($rawPoint[0]) !== 0x04) {
            $this->error('--public-key must be a base64url-encoded 65-byte uncompressed EC P-256 point (starts with 0x04).');
            return self::FAILURE;
        }

        $systemId    = $this->option('system-id')    ?: (string) Str::uuid();
        $agentId     = $this->option('agent-id')     ?: (string) Str::uuid();
        $rawCaps     = $this->option('capabilities') ?: 'otp_gateway';
        $capabilities = array_filter(array_map('trim', explode(',', $rawCaps)));

        $agent = Agent::updateOrCreate(
            ['public_key_id' => $publicKeyId],
            [
                'system_id'        => $systemId,
                'agent_id'         => $agentId,
                'agent_public_key' => $publicKey,
                'public_key_id'    => $publicKeyId,
                'fcm_token'        => $fcmToken,
                'capabilities'     => array_values($capabilities),
                'paired_at'        => now(),
            ]
        );

        $this->info("Agent registered successfully.");
        $this->table(
            ['Field', 'Value'],
            [
                ['agent_id',     $agent->agent_id],
                ['system_id',    $agent->system_id],
                ['public_key_id',$agent->public_key_id],
                ['capabilities', implode(', ', $agent->capabilities)],
                ['paired_at',    $agent->paired_at->toIso8601String()],
            ]
        );

        return self::SUCCESS;
    }
}
