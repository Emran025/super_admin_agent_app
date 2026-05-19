<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Verify OTP &mdash; Super Admin</title>
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: system-ui, -apple-system, sans-serif;
            background: #0f172a;
            color: #e2e8f0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .card {
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 12px;
            padding: 2rem;
            width: 100%;
            max-width: 400px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.4);
        }

        .card-header {
            text-align: center;
            margin-bottom: 1.5rem;
        }

        .card-header h1 {
            font-size: 1.5rem;
            font-weight: 700;
            color: #f8fafc;
            margin-bottom: 0.5rem;
        }

        .card-header p {
            font-size: 0.875rem;
            color: #94a3b8;
            line-height: 1.5;
        }

        .badge {
            display: inline-flex;
            align-items: center;
            gap: 0.375rem;
            background: #0f4c81;
            border: 1px solid #1d6fa5;
            color: #93c5fd;
            font-size: 0.75rem;
            font-weight: 600;
            padding: 0.25rem 0.75rem;
            border-radius: 9999px;
            margin-bottom: 1rem;
        }

        .badge::before {
            content: '';
            width: 6px;
            height: 6px;
            background: #3b82f6;
            border-radius: 50%;
        }

        .form-group {
            margin-bottom: 1.25rem;
        }

        label {
            display: block;
            font-size: 0.8125rem;
            font-weight: 600;
            color: #cbd5e1;
            margin-bottom: 0.5rem;
            letter-spacing: 0.025em;
            text-transform: uppercase;
        }

        input[type="text"] {
            width: 100%;
            background: #0f172a;
            border: 1px solid #475569;
            border-radius: 8px;
            color: #f1f5f9;
            font-size: 1.75rem;
            font-weight: 700;
            letter-spacing: 0.5rem;
            padding: 0.75rem 1rem;
            text-align: center;
            transition: border-color 0.15s;
            outline: none;
        }

        input[type="text"]:focus {
            border-color: #3b82f6;
            box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.25);
        }

        .error-list {
            background: #450a0a;
            border: 1px solid #991b1b;
            border-radius: 8px;
            color: #fca5a5;
            font-size: 0.8125rem;
            list-style: none;
            padding: 0.75rem 1rem;
            margin-bottom: 1.25rem;
        }

        .error-list li + li {
            margin-top: 0.25rem;
        }

        .success-msg {
            background: #052e16;
            border: 1px solid #166534;
            border-radius: 8px;
            color: #86efac;
            font-size: 0.8125rem;
            padding: 0.75rem 1rem;
            margin-bottom: 1.25rem;
        }

        button[type="submit"] {
            width: 100%;
            background: #3b82f6;
            border: none;
            border-radius: 8px;
            color: #fff;
            cursor: pointer;
            font-size: 0.9375rem;
            font-weight: 600;
            padding: 0.875rem;
            transition: background 0.15s, transform 0.1s;
        }

        button[type="submit"]:hover {
            background: #2563eb;
        }

        button[type="submit"]:active {
            transform: scale(0.98);
        }

        .hint {
            font-size: 0.75rem;
            color: #64748b;
            text-align: center;
            margin-top: 1.25rem;
            line-height: 1.6;
        }

        .security-note {
            background: #1a1f2e;
            border: 1px solid #2d3748;
            border-radius: 8px;
            font-size: 0.75rem;
            color: #64748b;
            padding: 0.75rem;
            margin-top: 1.25rem;
            line-height: 1.5;
        }

        .security-note strong {
            color: #94a3b8;
        }
    </style>
</head>
<body>
    <div class="card">
        <div class="card-header">
            <div class="badge">Push-Signed 2FA Active</div>
            <h1>Enter Verification Code</h1>
            <p>A one-time code was dispatched to your registered device via the Super Admin Agent.</p>
        </div>

        @if ($errors->any())
            <ul class="error-list">
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        @endif

        @if (session('success'))
            <div class="success-msg">{{ session('success') }}</div>
        @endif

        <form method="POST" action="{{ route('otp.verify') }}">
            @csrf

            <div class="form-group">
                <label for="otp">6-Digit Code</label>
                <input
                    type="text"
                    id="otp"
                    name="otp"
                    maxlength="6"
                    inputmode="numeric"
                    pattern="[0-9]{6}"
                    autocomplete="one-time-code"
                    autofocus
                    required
                    placeholder="000000"
                    value="{{ old('otp') }}"
                >
            </div>

            <button type="submit">Verify &amp; Continue</button>
        </form>

        <p class="hint">
            Didn't receive a code? Ensure your mobile agent is online and has
            SMS permissions granted. Codes expire in 5 minutes.
        </p>

        <div class="security-note">
            <strong>Zero-Trust Security:</strong> This code was sent via a cryptographically
            signed FCM push to your paired Android agent. The server never stores the
            plaintext code — only a bcrypt hash for verification.
        </div>
    </div>
</body>
</html>
