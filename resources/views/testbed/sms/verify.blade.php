<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SMS Gateway Testbed &mdash; Enter Code</title>
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
            max-width: 420px;
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
        .badge .dot {
            width: 6px;
            height: 6px;
            background: #16a34a;
            border-radius: 50%;
            animation: pulse 1.5s ease-in-out infinite;
        }
        @keyframes pulse {
            0%, 100% { opacity: 1; transform: scale(1); }
            50%       { opacity: 0.4; transform: scale(0.75); }
        }

        .greeting {
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

        .subtitle .phone-chip {
            display: inline-block;
            background: #0f172a;
            border: 1px solid #334155;
            border-radius: 6px;
            padding: 0.1rem 0.5rem;
            font-family: ui-monospace, monospace;
            font-size: 0.8125rem;
            color: #cbd5e1;
        }

        /* ── OTP digits ── */
        .otp-wrap {
            display: flex;
            gap: 0.5rem;
            justify-content: center;
            margin-bottom: 1.5rem;
        }

        .otp-digit {
            width: 48px;
            height: 60px;
            background: #0f172a;
            border: 2px solid #334155;
            border-radius: 10px;
            color: #f1f5f9;
            font-size: 1.75rem;
            font-weight: 700;
            text-align: center;
            outline: none;
            transition: border-color 0.15s, box-shadow 0.15s;
            caret-color: transparent;
        }

        .otp-digit:focus {
            border-color: #16a34a;
            box-shadow: 0 0 0 3px rgba(22, 163, 74, 0.2);
        }

        .otp-digit.filled {
            border-color: #4ade80;
        }

        /* Hidden actual input (single field submitted) */
        #otp { display: none; }

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
        }
        button[type="submit"]:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        button[type="submit"]:not(:disabled):hover { filter: brightness(1.1); }
        button[type="submit"]:not(:disabled):active { transform: scale(0.98); }

        .resend-row {
            text-align: center;
            margin-top: 1rem;
        }
        .resend-row a {
            font-size: 0.8125rem;
            color: #64748b;
            text-decoration: none;
        }
        .resend-row a:hover { color: #94a3b8; }

        /* ── vCard hint ── */
        .vcard-hint {
            display: flex;
            align-items: flex-start;
            gap: 0.6rem;
            background: #0f172a;
            border: 1px solid #1e293b;
            border-radius: 8px;
            padding: 0.875rem;
            margin-top: 1.5rem;
        }
        .vcard-hint p {
            font-size: 0.75rem;
            color: #64748b;
            line-height: 1.5;
        }
        .vcard-hint strong { color: #94a3b8; }
    </style>
</head>
<body>
<div class="card">

    <a href="{{ route('testbed.sms.phone') }}" class="back-link">
        &larr; Change details
    </a>

    <div class="badge"><div class="dot"></div> Code Sent</div>

    <p class="greeting">
        @if($contactName)
            Welcome, {{ $contactName }}!
        @else
            Enter your code
        @endif
    </p>

    <p class="subtitle">
        A 6-digit code was sent to
        <span class="phone-chip">{{ $phoneNumber ?? 'your number' }}</span>.
        The SMS also includes your contact card — tap <strong>Save</strong> in
        your messages app to store it automatically.
    </p>

    @if ($errors->any())
        <ul class="error-list">
            @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
            @endforeach
        </ul>
    @endif

    <form method="POST" action="{{ route('testbed.sms.verify') }}" id="otp-form">
        @csrf

        {{-- Hidden input submitted to server --}}
        <input type="text" id="otp" name="otp" maxlength="6" readonly>

        {{-- Visual digit boxes --}}
        <div class="otp-wrap" id="digit-wrap">
            @for ($i = 0; $i < 6; $i++)
                <input
                    type="text"
                    class="otp-digit"
                    maxlength="1"
                    inputmode="numeric"
                    pattern="[0-9]"
                    autocomplete="{{ $i === 0 ? 'one-time-code' : 'off' }}"
                    data-index="{{ $i }}"
                >
            @endfor
        </div>

        <button type="submit" id="submit-btn" disabled>Verify &amp; Complete Registration</button>
    </form>

    <div class="resend-row">
        <a href="{{ route('testbed.sms.phone') }}">Didn't receive it? Start again</a>
    </div>

    <div class="vcard-hint">
        <span style="font-size:1.1rem">🪪</span>
        <p>
            <strong>Contact card included:</strong> Your name and number were embedded
            as a vCard in the SMS. Compatible apps (Google Messages, Samsung Messages)
            will show a <em>"Save contact"</em> prompt automatically.
        </p>
    </div>

</div>

<script>
(function () {
    const digits   = Array.from(document.querySelectorAll('.otp-digit'));
    const hidden   = document.getElementById('otp');
    const btn      = document.getElementById('submit-btn');
    const form     = document.getElementById('otp-form');

    function sync() {
        const val = digits.map(d => d.value).join('');
        hidden.value = val;
        btn.disabled = val.length < 6;
        digits.forEach((d, i) => {
            d.classList.toggle('filled', d.value !== '');
        });
    }

    digits.forEach((digit, idx) => {
        digit.addEventListener('focus', () => digit.select());

        digit.addEventListener('input', e => {
            const raw = e.target.value.replace(/\D/g, '');

            // Handle paste of full code into first box
            if (raw.length > 1 && idx === 0) {
                raw.split('').slice(0, 6).forEach((ch, i) => {
                    if (digits[i]) digits[i].value = ch;
                });
                sync();
                const last = Math.min(raw.length, 5);
                digits[last].focus();
                return;
            }

            digit.value = raw.slice(-1);
            sync();
            if (raw && idx < 5) digits[idx + 1].focus();
        });

        digit.addEventListener('keydown', e => {
            if (e.key === 'Backspace') {
                if (!digit.value && idx > 0) {
                    digits[idx - 1].value = '';
                    digits[idx - 1].focus();
                } else {
                    digit.value = '';
                }
                sync();
                e.preventDefault();
            }
            if (e.key === 'ArrowLeft' && idx > 0) digits[idx - 1].focus();
            if (e.key === 'ArrowRight' && idx < 5) digits[idx + 1].focus();
        });
    });

    // Auto-submit when all 6 digits filled
    form.addEventListener('input', () => {
        if (hidden.value.length === 6) setTimeout(() => form.submit(), 120);
    });

    // Focus first digit on load
    digits[0].focus();
})();
</script>

</body>
</html>
