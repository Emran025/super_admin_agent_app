<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>2FA Push Testbed &mdash; Admin Login</title>
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
            max-width: 400px;
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
            background: #0c1a2e;
            border: 1px solid #1d4ed8;
            color: #60a5fa;
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
            background: #3b82f6;
            border-radius: 50%;
        }

        h1 {
            font-size: 1.5rem;
            font-weight: 700;
            color: #f8fafc;
            margin-bottom: 0.5rem;
        }

        .subtitle {
            font-size: 0.875rem;
            color: #94a3b8;
            line-height: 1.6;
            margin-bottom: 1.75rem;
        }

        .form-group { margin-bottom: 1.25rem; }

        label {
            display: block;
            font-size: 0.8125rem;
            font-weight: 600;
            color: #cbd5e1;
            margin-bottom: 0.5rem;
            letter-spacing: 0.02em;
            text-transform: uppercase;
        }

        input[type="text"],
        input[type="password"] {
            width: 100%;
            background: #0f172a;
            border: 1px solid #475569;
            border-radius: 8px;
            color: #f1f5f9;
            font-size: 1rem;
            padding: 0.75rem 1rem;
            outline: none;
            transition: border-color 0.15s;
        }

        input[type="text"]:focus,
        input[type="password"]:focus {
            border-color: #3b82f6;
            box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.2);
        }

        .credentials-hint {
            background: #0f172a;
            border: 1px solid #1e293b;
            border-radius: 8px;
            padding: 0.75rem 1rem;
            margin-bottom: 1.5rem;
            display: flex;
            gap: 1.5rem;
        }

        .credentials-hint .cred {
            display: flex;
            flex-direction: column;
            gap: 0.2rem;
        }

        .credentials-hint .cred span {
            font-size: 0.6875rem;
            color: #64748b;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            font-weight: 600;
        }

        .credentials-hint .cred code {
            font-size: 0.875rem;
            color: #93c5fd;
            font-family: ui-monospace, monospace;
        }

        .error-box {
            background: #450a0a;
            border: 1px solid #991b1b;
            border-radius: 8px;
            color: #fca5a5;
            font-size: 0.8125rem;
            padding: 0.75rem 1rem;
            margin-bottom: 1.25rem;
        }

        button[type="submit"] {
            width: 100%;
            background: #2563eb;
            border: none;
            border-radius: 8px;
            color: #fff;
            cursor: pointer;
            font-size: 0.9375rem;
            font-weight: 600;
            padding: 0.875rem;
            transition: filter 0.15s, transform 0.1s;
        }

        button[type="submit"]:hover { filter: brightness(1.1); }
        button[type="submit"]:active { transform: scale(0.98); }

        .flow-note {
            background: #0f172a;
            border: 1px solid #1e293b;
            border-radius: 8px;
            font-size: 0.75rem;
            color: #64748b;
            padding: 0.875rem;
            margin-top: 1.5rem;
            line-height: 1.5;
        }

        .flow-note strong { color: #94a3b8; }
    </style>
</head>
<body>
    <div class="card">
        <a href="<?php echo e(route('testbed.hub')); ?>" class="back-link">
            &larr; Back to Testbed Hub
        </a>

        <div class="badge">2FA Push</div>
        <h1>Admin Login</h1>
        <p class="subtitle">
            Enter the dummy credentials to trigger a 2FA push challenge. Your paired
            agent will receive the challenge via WebSocket and must approve it.
        </p>

        <div class="credentials-hint">
            <div class="cred">
                <span>Username</span>
                <code>admin</code>
            </div>
            <div class="cred">
                <span>Password</span>
                <code>testbed</code>
            </div>
        </div>

        <?php if($errors->has('credentials')): ?>
            <div class="error-box"><?php echo e($errors->first('credentials')); ?></div>
        <?php endif; ?>

        <form method="POST" action="<?php echo e(route('testbed.push.submit')); ?>">
            <?php echo csrf_field(); ?>

            <div class="form-group">
                <label for="username">Username</label>
                <input
                    type="text"
                    id="username"
                    name="username"
                    autocomplete="username"
                    autofocus
                    required
                    value="<?php echo e(old('username', 'admin')); ?>"
                >
            </div>

            <div class="form-group">
                <label for="password">Password</label>
                <input
                    type="password"
                    id="password"
                    name="password"
                    autocomplete="current-password"
                    required
                >
            </div>

            <button type="submit">Log In &rarr;</button>
        </form>

        <div class="flow-note">
            <strong>What happens:</strong> After valid credentials, the server sends a
            push challenge to your agent via Reverb. This page freezes and waits for
            the agent's approval before access is granted.
        </div>
    </div>
</body>
</html>
<?php /**PATH /home/runner/workspace/otp_server/resources/views/testbed/push/login.blade.php ENDPATH**/ ?>