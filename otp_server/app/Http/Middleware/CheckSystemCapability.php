<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * CheckSystemCapability — Explicit capability gate middleware.
 *
 * Must run after VerifyExternalSystem (which injects the authenticated system
 * into the request context). Asserts that the resolved ExternalSystem carries
 * the required capability before allowing the request to proceed.
 *
 * Capabilities: 'otp', 'payment', 'super_admin_login'
 *
 * Usage in routes:
 *   Route::post('/otp', ...)->middleware(['auth.external', 'capability:otp']);
 *
 * Aliased as: 'capability' in bootstrap/app.php.
 */
class CheckSystemCapability
{
    /**
     * @param  string $capability  The required capability string (e.g. 'otp').
     */
    public function handle(Request $request, Closure $next, string $capability): Response
    {
        $system = $request->attributes->get('external_system');

        if (!$system) {
            return response()->json(['error' => 'No authenticated external system found.'], 401);
        }

        if (!$system->hasCapability($capability)) {
            return response()->json([
                'error' => "This system does not have the '{$capability}' capability.",
            ], 403);
        }

        return $next($request);
    }
}
