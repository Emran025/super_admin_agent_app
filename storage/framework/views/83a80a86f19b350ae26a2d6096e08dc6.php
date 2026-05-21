



<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Super Admin Agent &mdash; Testbed</title>
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: system-ui, -apple-system, sans-serif;
            background: #0f172a;
            color: #e2e8f0;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 2rem 1rem;
        }

        .header {
            text-align: center;
            margin-bottom: 3rem;
        }

        .header h1 {
            font-size: 1.875rem;
            font-weight: 800;
            color: #f8fafc;
            letter-spacing: -0.02em;
        }

        .header p {
            margin-top: 0.75rem;
            font-size: 0.9375rem;
            color: #64748b;
            line-height: 1.6;
            max-width: 480px;
        }

        .cards {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 1.5rem;
            width: 100%;
            max-width: 820px;
        }

        @media (max-width: 640px) {
            .cards { grid-template-columns: 1fr; }
        }

        .card {
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 14px;
            padding: 2rem;
            display: flex;
            flex-direction: column;
            gap: 1.25rem;
            transition: border-color 0.2s, box-shadow 0.2s;
        }

        .card:hover {
            border-color: #475569;
            box-shadow: 0 8px 32px rgba(0,0,0,0.3);
        }

        .card-icon {
            width: 48px;
            height: 48px;
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.5rem;
        }

        .card-icon.green  { background: #052e16; border: 1px solid #166534; }
        .card-icon.blue   { background: #0c1a2e; border: 1px solid #1d4ed8; }

        .card-badge {
            display: inline-flex;
            align-items: center;
            gap: 0.375rem;
            font-size: 0.6875rem;
            font-weight: 700;
            letter-spacing: 0.08em;
            text-transform: uppercase;
            padding: 0.2rem 0.6rem;
            border-radius: 9999px;
        }

        .card-badge.green { background: #052e16; color: #4ade80; border: 1px solid #166534; }
        .card-badge.blue  { background: #0c1a2e; color: #60a5fa; border: 1px solid #1d4ed8; }

        .card h2 {
            font-size: 1.25rem;
            font-weight: 700;
            color: #f8fafc;
            line-height: 1.3;
        }

        .card p {
            font-size: 0.875rem;
            color: #94a3b8;
            line-height: 1.65;
            flex: 1;
        }

        .card .steps {
            list-style: none;
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
        }

        .card .steps li {
            display: flex;
            align-items: flex-start;
            gap: 0.625rem;
            font-size: 0.8125rem;
            color: #94a3b8;
            line-height: 1.4;
        }

        .card .steps li .step-num {
            flex-shrink: 0;
            width: 20px;
            height: 20px;
            border-radius: 50%;
            background: #334155;
            color: #cbd5e1;
            font-size: 0.6875rem;
            font-weight: 700;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .btn {
            display: block;
            text-align: center;
            padding: 0.875rem;
            border-radius: 8px;
            font-size: 0.9375rem;
            font-weight: 600;
            text-decoration: none;
            transition: filter 0.15s, transform 0.1s;
        }

        .btn:active { transform: scale(0.98); }

        .btn.green { background: #16a34a; color: #fff; }
        .btn.green:hover { filter: brightness(1.1); }
        .btn.blue  { background: #2563eb; color: #fff; }
        .btn.blue:hover  { filter: brightness(1.1); }

        .divider {
            display: flex;
            align-items: center;
            gap: 1rem;
            color: #334155;
            font-size: 0.75rem;
            margin: 0.5rem 0;
        }

        .divider::before,
        .divider::after {
            content: '';
            flex: 1;
            height: 1px;
            background: #334155;
        }

        .alert-success {
            background: #052e16;
            border: 1px solid #166534;
            border-radius: 8px;
            color: #86efac;
            font-size: 0.875rem;
            padding: 0.875rem 1rem;
            margin-bottom: 2rem;
            max-width: 820px;
            width: 100%;
            text-align: center;
        }

        .footer-note {
            margin-top: 3rem;
            font-size: 0.75rem;
            color: #334155;
            text-align: center;
            line-height: 1.6;
        }

        .card-icon.purple { background: #1e0a3c; border: 1px solid #7c3aed; }
        .card-badge.purple { background: #1e0a3c; color: #c4b5fd; border: 1px solid #7c3aed; }
        .btn.purple { background: #7c3aed; color: #fff; }
        .btn.purple:hover { filter: brightness(1.1); }

        .cards-wide { max-width: 820px; width: 100%; margin-top: 1.5rem; }
        .card-full { width: 100%; }

        .status-banner {
            width: 100%;
            max-width: 820px;
            padding: 1rem;
            border-radius: 12px;
            margin-bottom: 2rem;
            display: flex;
            align-items: center;
            gap: 0.75rem;
            font-size: 0.875rem;
            font-weight: 500;
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
            width: 8px;
            height: 8px;
            border-radius: 50%;
            display: inline-block;
        }
        
        .status-dot.connected {
            background: #4ade80;
            box-shadow: 0 0 8px #4ade80;
        }

        .status-dot.disconnected {
            background: #f87171;
            box-shadow: 0 0 8px #f87171;
        }
    </style>
</head>
<body>

    <?php if(session('success')): ?>
        <div class="alert-success"><?php echo e(session('success')); ?></div>
    <?php endif; ?>

    <div class="header">
        <h1>Super Admin Agent &mdash; Testbed</h1>
        <p>
            Choose a role to test. Each section simulates a completely different
            capability of the paired agent.
        </p>
    </div>

    <?php if($showQrCode): ?>
        <div class="card card-full" style="border-color: #7c3aed; background: #121026; margin-bottom: 2rem;">
            <div style="display: flex; flex-direction: column; align-items: center; text-align: center; gap: 1rem; padding: 1rem 0;">
                <div class="card-icon purple" aria-hidden="true" style="margin: 0 auto;">
                    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M10.5 13.5a3.5 3.5 0 005 0l1-1a3.5 3.5 0 00-5-5l-1 1" stroke="currentColor" stroke-width="1.2" fill="none" stroke-linecap="round" stroke-linejoin="round" />
                        <path d="M13.5 10.5a3.5 3.5 0 00-5 0l-1 1a3.5 3.5 0 005 5l1-1" stroke="currentColor" stroke-width="1.2" fill="none" stroke-linecap="round" stroke-linejoin="round" />
                    </svg>
                </div>
                <h2>Pair Mobile Agent</h2>
                <p style="max-width: 580px; color: #cbd5e1;">
                    Scan this QR code with the **Super Admin Agent** app to link it to this server.
                    Once paired, the agent will dynamically receive SMS OTP requests, 2FA push requests, and telemetry commands.
                </p>
                <div style="background: #ffffff; padding: 1.25rem; border-radius: 12px; margin: 1rem 0; box-shadow: 0 4px 20px rgba(0,0,0,0.5);">
                    <div id="agent-pairing-qrcode"></div>
                </div>
                <p style="font-size: 0.75rem; color: #64748b;">
                    Token matches <code>OTP_PAIRING_TOKEN</code> in your environment config. Expires in 24 hours.
                </p>
            </div>
        </div>
    <?php else: ?>
        <div class="card card-full" style="border-color: #166534; background: #0b1a11; margin-bottom: 2rem;">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1.5rem;">
                <div>
                    <h2 style="display: flex; align-items: center; gap: 0.5rem; color: #4ade80;">
                        <span class="status-dot <?php echo e($isAgentConnected ? 'connected' : 'disconnected'); ?>"></span>
                        Mobile Agent: <?php echo e($isAgentConnected ? 'Online' : 'Offline'); ?>

                    </h2>
                    <p style="color: #94a3b8; margin-top: 0.5rem;">
                        A device is currently paired and authenticated.
                    </p>
                    <div style="margin-top: 1rem; font-size: 0.8125rem; color: #cbd5e1; display: grid; gap: 0.25rem; text-align: left;">
                        <div><strong>Agent ID:</strong> <code class="mono" style="color: #e2e8f0;"><?php echo e($agent->agent_id); ?></code></div>
                        <div><strong>Public Key ID:</strong> <code class="mono" style="color: #e2e8f0;"><?php echo e($agent->public_key_id); ?></code></div>
                        <div><strong>Last Seen:</strong> <span style="color: #e2e8f0;"><?php echo e($agent->last_seen_at ? $agent->last_seen_at->diffForHumans() : 'Never'); ?></span></div>
                    </div>
                </div>
                <div>
                    <form method="POST" action="<?php echo e(route('testbed.agent.unpair')); ?>" onsubmit="return confirm('Are you sure you want to unpair this mobile agent? All credentials will be reset.')">
                        <?php echo csrf_field(); ?>
                        <button type="submit" class="btn btn-red" style="padding: 0.75rem 1.5rem; font-size: 0.875rem; border: none; cursor: pointer; border-radius: 8px;">
                            Force Unpair Agent
                        </button>
                    </form>
                </div>
            </div>
        </div>
    <?php endif; ?>

    <div class="cards">

        
        <div class="card">
            <div>
                <div class="card-icon green" aria-hidden="true">
                    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M7 2h10v2H7z" fill="currentColor" />
                        <rect x="6" y="5" width="12" height="14" rx="2" stroke="currentColor" stroke-width="1.2" fill="none" />
                        <circle cx="12" cy="18" r="0.8" fill="currentColor" />
                    </svg>
                </div>
            </div>
            <div>
                <span class="card-badge green">otp_gateway</span>
            </div>
            <h2>SMS Gateway</h2>
            <p>
                Simulate a third-party service that cannot send SMS and delegates
                to the agent. You enter a phone number, the agent sends a real SMS
                containing a one-time code, and you verify it here.
            </p>

            <div class="divider">Flow</div>

            <ul class="steps">
                <li>
                    <span class="step-num">1</span>
                    Enter a recipient phone number
                </li>
                <li>
                    <span class="step-num">2</span>
                    Agent receives command via Reverb &amp; sends a real SMS
                </li>
                <li>
                    <span class="step-num">3</span>
                    Enter the 6-digit code from the SMS to verify
                </li>
            </ul>

            <a href="<?php echo e(route('testbed.sms.phone')); ?>" class="btn green">
                Test SMS Gateway &rarr;
            </a>
        </div>

        
        <div class="card">
            <div>
                <div class="card-icon blue" aria-hidden="true">
                    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <rect x="6" y="10" width="12" height="8" rx="2" stroke="currentColor" stroke-width="1.2" fill="none" />
                        <path d="M9 10V8a3 3 0 016 0v2" stroke="currentColor" stroke-width="1.2" fill="none" stroke-linecap="round" />
                    </svg>
                </div>
            </div>
            <div>
                <span class="card-badge blue">two_fa</span>
            </div>
            <h2>2FA Push Approval</h2>
            <p>
                Simulate an admin control panel that uses push-based two-factor
                authentication. You log in with dummy credentials, then this page
                waits &mdash; live via WebSocket &mdash; for the agent to approve or reject.
            </p>

            <div class="divider">Flow</div>

            <ul class="steps">
                <li>
                    <span class="step-num">1</span>
                    Enter dummy credentials (admin / testbed)
                </li>
                <li>
                    <span class="step-num">2</span>
                    Agent receives push challenge via Reverb
                </li>
                <li>
                    <span class="step-num">3</span>
                    Page waits live for the agent's Approve / Reject response
                </li>
            </ul>

            <a href="<?php echo e(route('testbed.push.login')); ?>" class="btn blue">
                Test 2FA Push &rarr;
            </a>
        </div>

    </div>

    
    <div class="cards-wide">
        <div class="card card-full">
            <div>
                <div class="card-icon purple" aria-hidden="true">
                    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M10.5 13.5a3.5 3.5 0 005 0l1-1a3.5 3.5 0 00-5-5l-1 1" stroke="currentColor" stroke-width="1.2" fill="none" stroke-linecap="round" stroke-linejoin="round" />
                        <path d="M13.5 10.5a3.5 3.5 0 00-5 0l-1 1a3.5 3.5 0 005 5l1-1" stroke="currentColor" stroke-width="1.2" fill="none" stroke-linecap="round" stroke-linejoin="round" />
                    </svg>
                </div>
            </div>
            <div>
                <span class="card-badge purple">external_gateway</span>
            </div>
            <h2>System Pairing</h2>
            <p>
                Register a test external system and obtain its AES-256-GCM encryption key
                and API bearer token. The testbed SMS and 2FA flows use this system to
                exercise the full zero-trust encrypted API gateway end-to-end.
            </p>

            <div class="divider">Flow</div>

            <ul class="steps">
                <li>
                    <span class="step-num">1</span>
                    Create a test external system with selected capabilities
                </li>
                <li>
                    <span class="step-num">2</span>
                    Receive the API token &amp; AES-256 key (shown once, QR available)
                </li>
                <li>
                    <span class="step-num">3</span>
                    SMS Gateway and 2FA testbeds encrypt their payloads using this key
                </li>
            </ul>

            <a href="<?php echo e(route('testbed.pairing')); ?>" class="btn purple">
                Manage External Systems &rarr;
            </a>
        </div>
    </div>

    <?php if($showQrCode): ?>
        <script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>
        <script>
            new QRCode(document.getElementById('agent-pairing-qrcode'), {
                text: '<?php echo $qrCodeData; ?>',
                width: 300,
                height: 300,
                colorDark: '#000000',
                colorLight: '#ffffff',
                // Level L = 7 % error correction (vs default H = 30 %).
                // The code is displayed on a clean screen so damage recovery
                // is irrelevant. L produces the fewest modules, making each
                // cell larger and far easier for a phone camera to resolve.
                correctLevel: QRCode.CorrectLevel.L,
            });
        </script>
    <?php endif; ?>

</body>
</html>
<?php /**PATH /home/runner/workspace/otp_server/resources/views/testbed/hub.blade.php ENDPATH**/ ?>