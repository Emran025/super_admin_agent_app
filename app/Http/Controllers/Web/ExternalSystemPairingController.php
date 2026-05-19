<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Models\ExternalSystem;
use App\Services\PayloadEncryptionService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Str;
use Illuminate\View\View;

/**
 * System Pairing Testbed Controller.
 *
 * Provides a UI to create "Test External Systems" (is_test = true) for local
 * development and verification of the full encrypted API flow.
 *
 * The plaintext API token and encryption key are shown EXACTLY ONCE after
 * creation. They are never retrievable from the database after that point.
 *
 * Routes:
 *   GET  /testbed/system-pairing         — List existing test systems.
 *   POST /testbed/system-pairing         — Create a new test external system.
 *   POST /testbed/system-pairing/{id}/delete — Delete a test system.
 */
class ExternalSystemPairingController extends Controller
{
    // -------------------------------------------------------------------------
    // Show pairing page
    // -------------------------------------------------------------------------

    public function index(): View
    {
        $systems = ExternalSystem::where('is_test', true)
            ->latest()
            ->get();

        return view('testbed.system-pairing', compact('systems'));
    }

    // -------------------------------------------------------------------------
    // Create a new test external system
    // -------------------------------------------------------------------------

    public function store(Request $request): View
    {
        $request->validate([
            'name'         => ['required', 'string', 'max:100'],
            'capabilities' => ['required', 'array', 'min:1'],
            'capabilities.*' => ['in:otp,payment,super_admin_login'],
        ]);

        // Generate a high-entropy bearer token (256 bits) — shown only once.
        $plainToken = Str::random(64);
        // Generate a 32-byte AES-256 key — stored encrypted, shown only once.
        $plainKey   = base64_encode(random_bytes(32));

        $system = ExternalSystem::create([
            'name'                 => $request->input('name'),
            'api_token_hash'       => hash('sha256', $plainToken),
            'encryption_key'       => Crypt::encryptString($plainKey),
            'test_token_encrypted' => Crypt::encryptString($plainToken),
            'capabilities'         => $request->input('capabilities'),
            'is_test'              => true,
        ]);

        $systems = ExternalSystem::where('is_test', true)->latest()->get();

        // Credentials are passed to the view once; they are not stored in plaintext.
        return view('testbed.system-pairing', compact('systems'))
            ->with('newSystem', $system)
            ->with('newToken', $plainToken)
            ->with('newKey', $plainKey);
    }

    // -------------------------------------------------------------------------
    // Delete a test system
    // -------------------------------------------------------------------------

    public function destroy(string $id): RedirectResponse
    {
        $system = ExternalSystem::where('id', $id)
            ->where('is_test', true)
            ->firstOrFail();

        $system->delete();

        return redirect()->route('testbed.pairing')
            ->with('success', "Test system \"{$system->name}\" deleted.");
    }
}
