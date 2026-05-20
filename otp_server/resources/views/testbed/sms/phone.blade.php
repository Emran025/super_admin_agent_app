{{-- @var bool $isAgentConnected --}}
{{-- @var bool $hasTestSystem --}}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SMS Gateway Testbed &mdash; Register Account</title>
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
            padding: 1.5rem;
        }

        .card {
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 14px;
            padding: 2.25rem 2rem;
            width: 100%;
            max-width: 440px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.4);
        }

        .back-link {
            display: inline-flex;
            align-items: center;
            gap: 0.4rem;
            font-size: 0.8125rem;
            color: #64748b;
            text-decoration: none;
            margin-bottom: 1.5rem;
        }
        .back-link:hover { color: #94a3b8; }

        .badge {
            display: inline-flex;
            align-items: center;
            gap: 0.375rem;
            background: #052e16;
            border: 1px solid #166534;
            color: #4ade80;
            font-size: 0.6875rem;
            font-weight: 700;
            letter-spacing: 0.07em;
            text-transform: uppercase;
            padding: 0.25rem 0.65rem;
            border-radius: 9999px;
            margin-bottom: 1rem;
        }
        .badge::before {
            content: '';
            width: 6px;
            height: 6px;
            background: #16a34a;
            border-radius: 50%;
        }

        h1 {
            font-size: 1.5rem;
            font-weight: 700;
            color: #f8fafc;
            margin-bottom: 0.375rem;
        }

        .subtitle {
            font-size: 0.875rem;
            color: #94a3b8;
            line-height: 1.6;
            margin-bottom: 1.75rem;
        }

        /* ── Two-column name row ── */
        .name-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 0.75rem;
            margin-bottom: 1.125rem;
        }

        .form-group { margin-bottom: 1.125rem; }

        label {
            display: block;
            font-size: 0.75rem;
            font-weight: 600;
            color: #94a3b8;
            margin-bottom: 0.4rem;
            letter-spacing: 0.04em;
            text-transform: uppercase;
        }

        .required-star { color: #f87171; margin-left: 2px; }

        input[type="text"],
        input[type="tel"] {
            width: 100%;
            background: #0f172a;
            border: 1px solid #334155;
            border-radius: 8px;
            color: #f1f5f9;
            font-size: 0.9375rem;
            padding: 0.7rem 0.9rem;
            outline: none;
            transition: border-color 0.15s, box-shadow 0.15s;
        }

        input[type="text"]::placeholder,
        input[type="tel"]::placeholder { color: #475569; }

        input[type="text"]:focus,
        input[type="tel"]:focus {
            border-color: #16a34a;
            box-shadow: 0 0 0 3px rgba(22, 163, 74, 0.15);
        }

        input.error-field { border-color: #dc2626 !important; }

        /* ── Phone field with flag prefix ── */
        .phone-wrap {
            position: relative;
        }

        .phone-prefix {
            position: absolute;
            left: 0.9rem;
            top: 50%;
            transform: translateY(-50%);
            font-size: 0.9375rem;
            color: #64748b;
            pointer-events: none;
            user-select: none;
        }

        .phone-wrap input[type="tel"] {
            padding-left: 2.2rem;
            letter-spacing: 0.04em;
        }

        /* ── Divider ── */
        .divider {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            margin: 1.5rem 0 1.25rem;
        }
        .divider::before,
        .divider::after {
            content: '';
            flex: 1;
            height: 1px;
            background: #1e293b;
            border-top: 1px solid #334155;
        }
        .divider span {
            font-size: 0.6875rem;
            font-weight: 600;
            color: #475569;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            white-space: nowrap;
        }

        /* ── Errors ── */
        .error-list {
            background: #450a0a;
            border: 1px solid #7f1d1d;
            border-radius: 8px;
            color: #fca5a5;
            font-size: 0.8125rem;
            list-style: none;
            padding: 0.75rem 1rem;
            margin-bottom: 1.25rem;
        }
        .error-list li + li { margin-top: 0.25rem; }

        .field-error {
            font-size: 0.75rem;
            color: #f87171;
            margin-top: 0.3rem;
        }

        .alert-info {
            background: #0c1a2e;
            border: 1px solid #1d4ed8;
            border-radius: 8px;
            color: #93c5fd;
            font-size: 0.8125rem;
            padding: 0.75rem 1rem;
            margin-bottom: 1.25rem;
        }

        /* ── Submit ── */
        button[type="submit"] {
            width: 100%;
            background: #16a34a;
            border: none;
            border-radius: 8px;
            color: #fff;
            cursor: pointer;
            font-size: 0.9375rem;
            font-weight: 600;
            padding: 0.875rem;
            transition: filter 0.15s, transform 0.1s;
            margin-top: 0.25rem;
        }
        button[type="submit"]:hover { filter: brightness(1.1); }
        button[type="submit"]:active { transform: scale(0.98); }

        /* ── vCard note ── */
        .vcard-note {
            display: flex;
            align-items: flex-start;
            gap: 0.6rem;
            background: #0f172a;
            border: 1px solid #1e293b;
            border-radius: 8px;
            padding: 0.875rem;
            margin-top: 1.25rem;
        }

        .vcard-icon {
            flex-shrink: 0;
            width: 28px;
            height: 28px;
            background: #1e293b;
            border-radius: 6px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.875rem;
        }

        .vcard-note p {
            font-size: 0.75rem;
            color: #64748b;
            line-height: 1.5;
        }

        .vcard-note strong { color: #94a3b8; }

        .status-banner {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            font-size: 0.75rem;
            font-weight: 600;
            padding: 0.6rem 0.8rem;
            border-radius: 8px;
            margin-bottom: 1.25rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }

        .status-banner.connected {
            background: rgba(5, 46, 22, 0.4);
            border: 1px solid #166534;
            color: #4ade80;
        }

        .status-banner.disconnected {
            background: rgba(153, 27, 27, 0.4);
            border: 1px solid #991b1b;
            color: #f87171;
        }

        .status-dot {
            width: 6px;
            height: 6px;
            border-radius: 50%;
            display: inline-block;
        }

        .status-dot.connected {
            background: #4ade80;
            box-shadow: 0 0 6px #4ade80;
        }

        .status-dot.disconnected {
            background: #f87171;
            box-shadow: 0 0 6px #f87171;
        }
    </style>
</head>
<body>
<div class="card">

    <a href="{{ route('testbed.hub') }}" class="back-link">
        &larr; Back to Testbed Hub
    </a>

    <div class="badge">SMS Gateway</div>
    <h1>Create Account</h1>
    <p class="subtitle">
        Enter your details to register. A verification code will be sent to
        your phone via SMS — your contact card is included so you can save
        it in one tap.
    </p>

    @if ($isAgentConnected)
        <div class="status-banner connected">
            <span class="status-dot connected"></span>
            <span>Mobile Agent: Connected (Online)</span>
        </div>
    @else
        <div class="status-banner disconnected">
            <span class="status-dot disconnected"></span>
            <span>Mobile Agent: Offline (Commands will remain pending)</span>
        </div>
    @endif

    @if ($errors->any())
        <ul class="error-list">
            @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
            @endforeach
        </ul>
    @endif

    @if (isset($error))
        <div class="error-list"><li>{{ $error }}</li></div>
    @endif

    <form method="POST" action="{{ route('testbed.sms.dispatch') }}" novalidate>
        @csrf

        {{-- ── Name ── --}}
        <div class="divider"><span>Your details</span></div>

        <div class="form-group">
            <label for="full_name">
                Full Name <span class="required-star">*</span>
            </label>
            <input
                type="text"
                id="full_name"
                name="full_name"
                placeholder="e.g. Ahmad Al-Rashidi"
                autocomplete="name"
                autofocus
                required
                maxlength="80"
                value="{{ old('full_name') }}"
                class="{{ $errors->has('full_name') ? 'error-field' : '' }}"
            >
            @error('full_name')
                <p class="field-error">{{ $message }}</p>
            @enderror
        </div>

        {{-- ── Phone ── --}}
        <div class="divider"><span>Verification</span></div>

        <div class="form-group">
            <label for="phone_number">
                Phone Number <span class="required-star">*</span>
            </label>
            <div class="phone-wrap">
                <span class="phone-prefix" aria-hidden="true">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M6.62 10.79a15.05 15.05 0 006.59 6.59l2.2-2.2a1 1 0 011.01-.24c1.12.37 2.33.57 3.57.57a1 1 0 011 1V20a1 1 0 01-1 1A17 17 0 013 4a1 1 0 011-1h2.5a1 1 0 011 1c0 1.24.2 2.45.57 3.57a1 1 0 01-.24 1.01l-2.21 2.21z" stroke="currentColor" stroke-width="1" fill="none" stroke-linecap="round" stroke-linejoin="round" />
                    </svg>
                </span>
                <input
                    type="tel"
                    id="phone_number"
                    name="phone_number"
                    placeholder="+966 5XX XXX XXXX"
                    autocomplete="tel"
                    required
                    value="{{ old('phone_number') }}"
                    class="{{ $errors->has('phone_number') ? 'error-field' : '' }}"
                >
            </div>
            @error('phone_number')
                <p class="field-error">{{ $message }}</p>
            @enderror
        </div>

        <button type="submit">Send Verification Code &rarr;</button>
    </form>

    <div class="vcard-note">
        <div class="vcard-icon" aria-hidden="true">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect x="3" y="4" width="18" height="16" rx="2" stroke="currentColor" stroke-width="1.2" fill="none" />
                <circle cx="8" cy="10" r="2" stroke="currentColor" stroke-width="1.2" fill="none" />
                <path d="M14 8h4M14 12h4" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" />
            </svg>
        </div>
        <p>
            <strong>Auto-save contact:</strong> The SMS will include your name and
            number as a vCard. Tap <em>"Save contact"</em> in your SMS app to store
            your details with a single tap — no manual entry needed.
        </p>
    </div>

</div>
</body>
</html>
