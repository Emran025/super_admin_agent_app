<?php

namespace App\Http\Middleware;

use App\Models\ExternalSystem;
use App\Services\PayloadEncryptionService;
use Closure;
use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * VerifyExternalSystem — API Gateway authentication middleware.
 *
 * Every inbound external API request must pass through this middleware before
 * any controller logic runs. It enforces:
 *
 *   1. Bearer token extraction from the Authorization header.
 *   2. SHA-256 hash lookup against external_systems.api_token_hash.
 *   3. AES-256-GCM decryption of the request body using the system's encryption key.
 *   4. Replacement of the request's parameter bag with the decrypted parameters so
 *      controllers receive plain data — never raw ciphertext.
 *   5. Injection of the authenticated ExternalSystem into the request context.
 *   6. Production isolation: test systems (is_test = true) are rejected when the
 *      application is running in production mode.
 *
 * Aliased as: 'auth.external' in bootstrap/app.php.
 */
class VerifyExternalSystem
{
    public function __construct(
        private readonly PayloadEncryptionService $encryptionService,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        // ── Step 1: Extract Bearer token ─────────────────────────────────────
        $authHeader = $request->header('Authorization', '');
        if (!str_starts_with($authHeader, 'Bearer ')) {
            return response()->json(['error' => 'Missing or malformed Authorization header.'], 401);
        }

        $token     = substr($authHeader, 7);
        $tokenHash = hash('sha256', $token);

        // ── Step 2: Resolve the ExternalSystem ───────────────────────────────
        $system = ExternalSystem::where('api_token_hash', $tokenHash)->first();

        if (!$system) {
            return response()->json(['error' => 'Invalid API token.'], 401);
        }

        // ── Step 3: Production isolation guard (Constraint 2.2) ─────────────
        if ($system->is_test && app()->isProduction()) {
            return response()->json(['error' => 'Test systems are not permitted in production.'], 403);
        }

        // ── Step 4: Decrypt the request payload ──────────────────────────────
        $encryptedPayload = $request->input('encrypted_payload');
        $iv               = $request->input('iv');
        $tag              = $request->input('tag');

        if (!$encryptedPayload || !$iv || !$tag) {
            return response()->json(['error' => 'Missing encrypted envelope fields (encrypted_payload, iv, tag).'], 400);
        }

        try {
            $plainKey       = $system->getPlaintextEncryptionKey();
            $decryptedData  = $this->encryptionService->decrypt($encryptedPayload, $plainKey, $iv, $tag);
        } catch (DecryptException $e) {
            return response()->json(['error' => 'Payload decryption failed. Ciphertext may be tampered.'], 400);
        }

        // ── Step 5: Replace request payload with decrypted parameters ────────
        $request->replace($decryptedData);

        // ── Step 6: Inject the authenticated system into request context ─────
        $request->attributes->set('external_system', $system);

        // Update last_used_at timestamp.
        $system->update(['last_used_at' => now()]);

        return $next($request);
    }
}
