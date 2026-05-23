{{-- @var string $reverbScheme --}}
{{-- @var string $reverbHost --}}
{{-- @var int $reverbPort --}}
{{-- @var string $reverbAppKey --}}
{{-- @var string $challengeId --}}
{{-- @var string $expiresAt --}}
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>2FA Push Testbed &mdash; Waiting for Approval</title>
    <style>
        *,
        *::before,
        *::after {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

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
            padding: 2.5rem 2rem;
            width: 100%;
            max-width: 400px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.4);
            text-align: center;
            transition: border-color 0.4s;
        }

        .card.approved {
            border-color: #16a34a;
        }

        .card.rejected {
            border-color: #dc2626;
        }

        /* ── Spinner ── */
        .spinner-wrap {
            display: flex;
            justify-content: center;
            margin-bottom: 1.75rem;
        }

        .spinner {
            width: 64px;
            height: 64px;
            border: 4px solid #334155;
            border-top-color: #3b82f6;
            border-radius: 50%;
            animation: spin 0.9s linear infinite;
        }

        @keyframes spin {
            to {
                transform: rotate(360deg);
            }
        }

        /* ── Result icons ── */
        .result-icon {
            display: none;
            width: 64px;
            height: 64px;
            border-radius: 50%;
            margin: 0 auto 1.75rem;
            align-items: center;
            justify-content: center;
            font-size: 2rem;
        }

        .result-icon.approved {
            display: flex;
            background: #052e16;
        }

        .result-icon.rejected {
            display: flex;
            background: #450a0a;
        }

        .badge {
            display: inline-flex;
            align-items: center;
            gap: 0.375rem;
            background: #0c1a2e;
            border: 1px solid #1d4ed8;
            color: #60a5fa;
            font-size: 0.6875rem;
            font-weight: 700;
            letter-spacing: 0.07em;
            text-transform: uppercase;
            padding: 0.25rem 0.65rem;
            border-radius: 9999px;
            margin-bottom: 1.25rem;
        }

        .badge .dot {
            width: 6px;
            height: 6px;
            background: #3b82f6;
            border-radius: 50%;
            animation: pulse 1.4s ease-in-out infinite;
        }

        @keyframes pulse {

            0%,
            100% {
                opacity: 1;
                transform: scale(1);
            }

            50% {
                opacity: 0.3;
                transform: scale(0.7);
            }
        }

        h1 {
            font-size: 1.5rem;
            font-weight: 700;
            color: #f8fafc;
            margin-bottom: 0.625rem;
        }

        .subtitle {
            font-size: 0.875rem;
            color: #94a3b8;
            line-height: 1.65;
            margin-bottom: 1.5rem;
        }

        /* ── Status label ── */
        #status-label {
            font-size: 0.8125rem;
            color: #64748b;
            margin-bottom: 1.5rem;
            min-height: 1.25rem;
        }

        /* ── Timer bar ── */
        .timer-bar-wrap {
            background: #0f172a;
            border-radius: 9999px;
            height: 4px;
            overflow: hidden;
            margin-bottom: 2rem;
        }

        .timer-bar {
            height: 100%;
            background: #3b82f6;
            border-radius: 9999px;
            width: 100%;
            transition: width 1s linear, background 0.5s;
        }

        /* ── Retry button (hidden until needed) ── */
        #retry-btn {
            display: none;
            width: 100%;
            background: #2563eb;
            border: none;
            border-radius: 8px;
            color: #fff;
            cursor: pointer;
            font-size: 0.9375rem;
            font-weight: 600;
            padding: 0.875rem;
            text-decoration: none;
            transition: filter 0.15s;
        }

        #retry-btn:hover {
            filter: brightness(1.1);
        }

        .ws-status {
            font-size: 0.6875rem;
            color: #475569;
            margin-top: 1.5rem;
        }

        .ws-status.connected {
            color: #22c55e;
        }

        .ws-status.error {
            color: #f87171;
        }
    </style>
</head>

<body>

    <div class="card" id="card"
        data-reverb-scheme='@json($reverbScheme)'
        data-reverb-host='@json($reverbHost)'
        data-reverb-port='@json($reverbPort)'
        data-reverb-app-key='@json($reverbAppKey)'
        data-challenge-id='@json($challengeId)'
        data-expires-at='@json($expiresAt)'
        data-poll-url='@json(route("testbed.push.poll"))'
        data-hub-url='@json(route("testbed.hub"))'
        data-login-url='@json(route("testbed.push.login"))'>

        {{-- Spinner (shown while waiting) --}}
        <div class="spinner-wrap" id="spinner-wrap">
            <div class="spinner"></div>
        </div>

        {{-- Result icons (shown after decision) --}}
        <div class="result-icon approved" id="icon-approved" style="display:none">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
                <circle cx="12" cy="12" r="11" stroke="currentColor" stroke-width="2" fill="none" />
                <path d="M7.5 12.5L10.5 15.5L16.5 9.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
        </div>
        <div class="result-icon rejected" id="icon-rejected" style="display:none">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
                <circle cx="12" cy="12" r="11" stroke="currentColor" stroke-width="2" fill="none" />
                <path d="M8 8L16 16M16 8L8 16" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
            </svg>
        </div>

        <div class="badge">
            <div class="dot"></div> Awaiting Push Approval
        </div>

        <h1 id="main-title">Waiting for Agent</h1>
        <p class="subtitle" id="main-subtitle">
            A push notification was sent to your Super Admin Agent via Reverb.
            Open the app and tap <strong>Approve</strong> to continue.
        </p>

        <div id="status-label">Connecting to live channel&hellip;</div>

        <div class="timer-bar-wrap">
            <div class="timer-bar" id="timer-bar"></div>
        </div>

        <a href="{{ route('testbed.push.login') }}" id="retry-btn">Try Again &rarr;</a>

        <div class="ws-status" id="ws-status">WebSocket: connecting&hellip;</div>

        {{-- ── Broadcast diagnosis panel ───────────────────────────────── --}}
        <details style="margin-top:1.5rem;text-align:left;font-size:.78rem;color:#94a3b8;">
            <summary style="cursor:pointer;color:#cbd5e1;font-weight:600;list-style:none;user-select:none;">
                ▶ Broadcast diagnostics
            </summary>
            <div style="margin-top:.6rem;background:#0f172a;border-radius:8px;padding:.75rem 1rem;line-height:1.7;word-break:break-all;">
                <div>
                    <span style="color:#64748b;">Broadcast sent:</span>
                    @if($broadcastOk === true)
                        <span style="color:#22c55e;font-weight:600;">✓ YES</span>
                    @elseif($broadcastOk === false && $broadcastError)
                        <span style="color:#f87171;font-weight:600;">✗ FAILED — {{ $broadcastError }}</span>
                    @else
                        <span style="color:#94a3b8;">unknown</span>
                    @endif
                </div>
                <div style="margin-top:.4rem;">
                    <span style="color:#64748b;">Agent system_id targeted:</span><br>
                    <code style="color:#38bdf8;">{{ $agentSystemId ?? '(none)' }}</code>
                </div>
                <div style="margin-top:.4rem;">
                    <span style="color:#64748b;">Reverb channel:</span><br>
                    <code style="color:#38bdf8;">private-agent.{{ $agentSystemId ?? '?' }}</code>
                </div>
                <div style="margin-top:.4rem;color:#475569;font-size:.72rem;">
                    If the agent system_id above does not match the system_id your phone
                    subscribed with (<code>private-agent.04d2bf2d-…</code>), the challenge
                    was broadcast to the wrong channel. Check that only one agent record
                    exists in the database, or link the external system to the correct agent
                    on the System Pairing page.
                </div>
            </div>
        </details>
        {{-- ──────────────────────────────────────────────────────────────── --}}
    </div>

    <script>
        // Read server config from `#card` dataset to avoid Blade directives inside JS
        const _card = document.getElementById('card');
        const _ds = _card?.dataset || {};

        function _maybeParse(v) {
            if (v === undefined || v === null || v === '') return null;
            try {
                return JSON.parse(v);
            } catch {
                return v;
            }
        }

        const REVERB_SCHEME = _maybeParse(_ds.reverbScheme) || 'ws';
        const REVERB_HOST = _maybeParse(_ds.reverbHost);
        const REVERB_PORT = _maybeParse(_ds.reverbPort);
        const REVERB_APP_KEY = _maybeParse(_ds.reverbAppKey);
        const CHALLENGE_ID = _maybeParse(_ds.challengeId);
        const EXPIRES_AT = new Date(_maybeParse(_ds.expiresAt) || Date.now());
        const POLL_URL = _maybeParse(_ds.pollUrl) || null;
        const HUB_URL = _maybeParse(_ds.hubUrl) || null;
        const LOGIN_URL = _maybeParse(_ds.loginUrl) || null;

        // ── DOM refs ────────────────────────────────────────────────────────────────
        const card = document.getElementById('card');
        const spinnerWrap = document.getElementById('spinner-wrap');
        const iconApproved = document.getElementById('icon-approved');
        const iconRejected = document.getElementById('icon-rejected');
        const mainTitle = document.getElementById('main-title');
        const mainSubtitle = document.getElementById('main-subtitle');
        const statusLabel = document.getElementById('status-label');
        const timerBar = document.getElementById('timer-bar');
        const retryBtn = document.getElementById('retry-btn');
        const wsStatus = document.getElementById('ws-status');

        // ── Countdown timer ─────────────────────────────────────────────────────────
        const totalMs = EXPIRES_AT - Date.now();
        let resolved = false;

        function updateTimer() {
            if (resolved) return;
            const remaining = EXPIRES_AT - Date.now();
            if (remaining <= 0) {
                timerBar.style.width = '0%';
                timerBar.style.background = '#ef4444';
                handleDecision('expired');
                return;
            }
            const pct = Math.min(100, (remaining / totalMs) * 100);
            timerBar.style.width = pct + '%';
            if (pct < 25) timerBar.style.background = '#f97316';
        }

        const timerInterval = setInterval(updateTimer, 1000);
        updateTimer();

        // ── Decision handler ────────────────────────────────────────────────────────
        function handleDecision(decision) {
            if (resolved) return;
            resolved = true;
            clearInterval(timerInterval);

            spinnerWrap.style.display = 'none';

            if (decision === 'approved') {
                card.classList.add('approved');
                iconApproved.style.display = 'flex';
                mainTitle.textContent = 'Access Granted';
                mainSubtitle.innerHTML = 'The agent <strong>approved</strong> your login. Redirecting&hellip;';
                statusLabel.textContent = '';
                timerBar.style.background = '#16a34a';
                setTimeout(() => {
                    window.location.href = HUB_URL + '?success=1';
                }, 1800);
            } else if (decision === 'rejected') {
                card.classList.add('rejected');
                iconRejected.style.display = 'flex';
                mainTitle.textContent = 'Access Denied';
                mainSubtitle.innerHTML = 'The agent <strong>rejected</strong> the login request.';
                statusLabel.textContent = '';
                timerBar.style.background = '#ef4444';
                retryBtn.style.display = 'block';
            } else {
                // expired
                mainTitle.textContent = 'Challenge Expired';
                mainSubtitle.textContent = 'The agent did not respond in time. Please try again.';
                statusLabel.textContent = '';
                retryBtn.style.display = 'block';
            }
        }

        // ── Reverb / Pusher WebSocket ────────────────────────────────────────────────
        // Uses the Pusher JS client which Reverb is 100% compatible with.
        // The public channel push-2fa-result.{challengeId} requires no auth.
        (function connectReverb() {
            const wsUrl = `${REVERB_SCHEME}://${REVERB_HOST}:${REVERB_PORT}/app/${REVERB_APP_KEY}?protocol=7&client=js-testbed&version=1.0`;
            let socket;

            try {
                socket = new WebSocket(wsUrl);
            } catch (e) {
                wsStatus.textContent = 'WebSocket: failed to connect — falling back to polling';
                wsStatus.className = 'ws-status error';
                startPolling();
                return;
            }

            const channelName = `push-2fa-result.${CHALLENGE_ID}`;

            // If the Pusher handshake (pusher:connection_established) does not arrive
            // within 6 seconds of the socket opening, the socket is connected to the
            // web server rather than Reverb (no WebSocket proxy configured). Close it
            // and start the polling fallback so the decision is still delivered.
            let handshakeTimer = null;
            let handshakeReceived = false;

            socket.addEventListener('open', () => {
                wsStatus.textContent = 'WebSocket: connected';
                wsStatus.className = 'ws-status connected';

                handshakeTimer = setTimeout(() => {
                    if (!handshakeReceived) {
                        wsStatus.textContent = 'WebSocket: no Pusher handshake — falling back to polling';
                        wsStatus.className = 'ws-status error';
                        socket.close();
                        startPolling();
                    }
                }, 6000);
            });

            socket.addEventListener('message', (event) => {
                let msg;
                try {
                    msg = JSON.parse(event.data);
                } catch {
                    return;
                }

                const evtName = msg.event;

                // Pusher handshake
                if (evtName === 'pusher:connection_established') {
                    handshakeReceived = true;
                    clearTimeout(handshakeTimer);
                    statusLabel.textContent = 'Live channel established — waiting for agent\u2026';
                    // Subscribe to the public channel
                    socket.send(JSON.stringify({
                        event: 'pusher:subscribe',
                        data: {
                            channel: channelName
                        }
                    }));
                    return;
                }

                // Respond to pings
                if (evtName === 'pusher:ping') {
                    socket.send(JSON.stringify({
                        event: 'pusher:pong',
                        data: {}
                    }));
                    return;
                }

                // Agent decision event
                if (evtName === 'decision.made') {
                    let data = msg.data;
                    if (typeof data === 'string') {
                        try {
                            data = JSON.parse(data);
                        } catch {
                            return;
                        }
                    }
                    if (data && data.challenge_id === CHALLENGE_ID) {
                        handleDecision(data.decision);
                    }
                }
            });

            socket.addEventListener('error', () => {
                wsStatus.textContent = 'WebSocket: error — falling back to polling';
                wsStatus.className = 'ws-status error';
            });

            socket.addEventListener('close', () => {
                if (!resolved) {
                    wsStatus.textContent = 'WebSocket: disconnected — polling for result';
                    wsStatus.className = 'ws-status error';
                    startPolling();
                }
            });
        })();

        // ── Polling fallback ─────────────────────────────────────────────────────────
        // Polls the server every 3 seconds as a safety net in case the WebSocket
        // connection cannot be established (e.g. network issues, Reverb not running).
        let pollHandle;

        function startPolling() {
            if (pollHandle) return;
            statusLabel.textContent = 'Polling for result every 3s…';
            pollHandle = setInterval(async () => {
                if (resolved) {
                    clearInterval(pollHandle);
                    return;
                }
                try {
                    const res = await fetch(POLL_URL, {
                        credentials: 'same-origin'
                    });
                    const json = await res.json();
                    if (json.status === 'approved') handleDecision('approved');
                    else if (json.status === 'rejected') handleDecision('rejected');
                    else if (json.expired) handleDecision('expired');
                } catch {}
            }, 3000);
        }
    </script>

</body>

</html>