<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Pairing &mdash; Testbed</title>
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
            flex-direction: column;
            align-items: center;
            padding: 2rem 1rem;
        }

        .header {
            text-align: center;
            margin-bottom: 2.5rem;
            max-width: 680px;
        }

        .header h1 {
            font-size: 1.75rem;
            font-weight: 800;
            color: #f8fafc;
            letter-spacing: -0.02em;
        }

        .header p {
            margin-top: 0.625rem;
            font-size: 0.9375rem;
            color: #64748b;
            line-height: 1.6;
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

        .back-link:hover {
            color: #94a3b8;
        }

        .page {
            width: 100%;
            max-width: 760px;
        }

        .card {
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 14px;
            padding: 2rem;
            margin-bottom: 1.5rem;
        }

        .card h2 {
            font-size: 1.125rem;
            font-weight: 700;
            color: #f8fafc;
            margin-bottom: 0.25rem;
        }

        .card .subtitle {
            font-size: 0.85rem;
            color: #64748b;
            margin-bottom: 1.5rem;
            line-height: 1.5;
        }

        label {
            display: block;
            font-size: 0.75rem;
            font-weight: 600;
            color: #94a3b8;
            margin-bottom: 0.4rem;
            letter-spacing: 0.04em;
            text-transform: uppercase;
        }

        input[type="text"] {
            width: 100%;
            background: #0f172a;
            border: 1px solid #334155;
            border-radius: 8px;
            color: #f1f5f9;
            font-size: 0.9375rem;
            padding: 0.7rem 0.9rem;
            outline: none;
            transition: border-color 0.15s;
        }

        input[type="text"]:focus {
            border-color: #7c3aed;
            box-shadow: 0 0 0 3px rgba(124, 58, 237, 0.15);
        }

        .form-group {
            margin-bottom: 1.125rem;
        }

        .checkbox-group {
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
            margin-bottom: 1.125rem;
        }

        .checkbox-label {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            font-size: 0.875rem;
            color: #cbd5e1;
            cursor: pointer;
        }

        .checkbox-label input[type="checkbox"] {
            accent-color: #7c3aed;
            width: 15px;
            height: 15px;
        }

        .btn {
            display: inline-block;
            padding: 0.75rem 1.5rem;
            border-radius: 8px;
            font-size: 0.9375rem;
            font-weight: 600;
            text-decoration: none;
            border: none;
            cursor: pointer;
            transition: filter 0.15s;
        }

        .btn-purple {
            background: #7c3aed;
            color: #fff;
        }

        .btn-purple:hover {
            filter: brightness(1.1);
        }

        .btn-red {
            background: #dc2626;
            color: #fff;
            font-size: 0.8rem;
            padding: 0.4rem 0.875rem;
        }

        .btn-red:hover {
            filter: brightness(1.1);
        }

        .btn-sm {
            padding: 0.4rem 0.875rem;
            font-size: 0.8125rem;
        }

        .alert-success {
            background: #052e16;
            border: 1px solid #166534;
            border-radius: 8px;
            color: #86efac;
            font-size: 0.875rem;
            padding: 0.875rem 1rem;
            margin-bottom: 1.5rem;
        }

        .alert-warning {
            background: #1c1400;
            border: 1px solid #854d0e;
            border-radius: 10px;
            padding: 1.25rem;
            margin-bottom: 1.5rem;
        }

        .alert-warning h3 {
            color: #fbbf24;
            font-size: 0.9375rem;
            margin-bottom: 0.75rem;
        }

        .cred-block {
            background: #0f172a;
            border: 1px solid #334155;
            border-radius: 8px;
            padding: 1rem;
            margin-bottom: 0.75rem;
        }

        .cred-block .cred-label {
            font-size: 0.6875rem;
            font-weight: 700;
            color: #64748b;
            letter-spacing: 0.06em;
            text-transform: uppercase;
            margin-bottom: 0.375rem;
        }

        .cred-block code {
            display: block;
            font-family: 'Courier New', monospace;
            font-size: 0.8125rem;
            color: #fde68a;
            word-break: break-all;
            line-height: 1.5;
        }

        .copy-btn {
            margin-top: 0.4rem;
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 5px;
            color: #94a3b8;
            font-size: 0.75rem;
            padding: 0.25rem 0.6rem;
            cursor: pointer;
            transition: background 0.15s;
        }

        .copy-btn:hover {
            background: #334155;
        }

        .qr-block {
            display: flex;
            flex-direction: column;
            align-items: center;
            margin: 1rem 0;
        }

        #qrcode {
            display: inline-block;
        }

        .qr-note {
            font-size: 0.75rem;
            color: #64748b;
            margin-top: 0.5rem;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 0.875rem;
        }

        th {
            text-align: left;
            padding: 0.6rem 0.75rem;
            color: #64748b;
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.04em;
            border-bottom: 1px solid #334155;
        }

        td {
            padding: 0.75rem;
            border-bottom: 1px solid #1e293b;
            color: #cbd5e1;
            vertical-align: middle;
        }

        .badge-pill {
            display: inline-flex;
            align-items: center;
            gap: 0.25rem;
            font-size: 0.6875rem;
            font-weight: 700;
            letter-spacing: 0.06em;
            text-transform: uppercase;
            padding: 0.2rem 0.5rem;
            border-radius: 9999px;
        }

        .badge-purple {
            background: #2e1065;
            color: #c4b5fd;
            border: 1px solid #7c3aed;
        }

        .badge-yellow {
            background: #1c1400;
            color: #fcd34d;
            border: 1px solid #92400e;
        }

        .empty-state {
            color: #475569;
            font-size: 0.875rem;
            text-align: center;
            padding: 2rem 0;
        }

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

        .error-list li+li {
            margin-top: 0.25rem;
        }

        .section-title {
            font-size: 1rem;
            font-weight: 700;
            color: #f8fafc;
            margin-bottom: 1rem;
        }

        .mono {
            font-family: monospace;
            font-size: 0.8125rem;
            color: #94a3b8;
        }
    </style>
</head>

<body>
    <div class="page">
        <a href="<?php echo e(route('testbed.hub')); ?>" class="back-link">&larr; Back to Testbed Hub</a>

        <div class="header">
            <h1>🔗 System Pairing</h1>
            <p>
                Create "Test External Systems" (<code>is_test = true</code>) to verify the full
                AES-256-GCM encrypted API gateway flow without affecting production telemetry.
            </p>
        </div>

        <?php if(session('success')): ?>
        <div class="alert-success"><?php echo e(session('success')); ?></div>
        <?php endif; ?>

        
        <?php if(isset($newSystem, $newToken, $newKey)): ?>
        <div class="alert-warning">
            <h3>⚠️ Save these credentials now — they will not be shown again</h3>
            <p style="color:#fcd34d;font-size:0.8125rem;margin-bottom:1rem;">
                The plaintext API token and encryption key are shown exactly once.
                They are never retrievable from the database.
            </p>

            <div class="cred-block">
                <div class="cred-label">System ID (UUID)</div>
                <code id="cred-id"><?php echo e($newSystem->id); ?></code>
                <button class="copy-btn" onclick="copyText('cred-id', this)">Copy</button>
            </div>
            <div class="cred-block">
                <div class="cred-label">API Bearer Token</div>
                <code id="cred-token"><?php echo e($newToken); ?></code>
                <button class="copy-btn" onclick="copyText('cred-token', this)">Copy</button>
            </div>
            <div class="cred-block">
                <div class="cred-label">AES-256 Encryption Key (base64, 32 bytes)</div>
                <code id="cred-key"><?php echo e($newKey); ?></code>
                <button class="copy-btn" onclick="copyText('cred-key', this)">Copy</button>
            </div>
            <div class="cred-block">
                <div class="cred-label">Capabilities</div>
                <code><?php echo e(implode(', ', $newSystem->capabilities)); ?></code>
            </div>

            <div class="qr-block">
                <div id="qrcode" data-capabilities='<?php echo json_encode($newSystem->capabilities, 15, 512) ?>'></div>
                <div class="qr-note">Scan with the mobile agent to link this external system.</div>
            </div>
        </div>

        <script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>
        <script>
            const config = JSON.stringify({
                system_id: "<?php echo e($newSystem->id); ?>",
                api_token: "<?php echo e($newToken); ?>",
                encryption_key: "<?php echo e($newKey); ?>",
                capabilities: JSON.parse(document.getElementById('qrcode').dataset.capabilities),
                is_test: true
            });
            new QRCode(document.getElementById('qrcode'), {
                text: config,
                width: 200,
                height: 200,
                colorDark: '#f8fafc',
                colorLight: '#0f172a',
            });
        </script>
        <?php endif; ?>

        
        <div class="card">
            <h2>Create Test External System</h2>
            <p class="subtitle">
                All created systems are automatically marked <code>is_test = true</code>.
                In production mode, test systems are rejected by the gateway.
            </p>

            <?php if($errors->any()): ?>
            <ul class="error-list">
                <?php $__currentLoopData = $errors->all(); $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $error): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                <li><?php echo e($error); ?></li>
                <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?>
            </ul>
            <?php endif; ?>

            <form method="POST" action="<?php echo e(route('testbed.pairing.store')); ?>">
                <?php echo csrf_field(); ?>
                <div class="form-group">
                    <label for="name">System Name</label>
                    <input type="text" id="name" name="name" placeholder="e.g. My Test App" value="<?php echo e(old('name')); ?>" required maxlength="100">
                </div>
                <div class="form-group">
                    <label>Capabilities <span style="color:#f87171">*</span></label>
                    <div class="checkbox-group">
                        <label class="checkbox-label">
                            <input type="checkbox" name="capabilities[]" value="otp" <?php echo e(in_array('otp', old('capabilities', ['otp'])) ? 'checked' : ''); ?>>
                            <span><strong>otp</strong> — POST /api/v1/external/otp</span>
                        </label>
                        <label class="checkbox-label">
                            <input type="checkbox" name="capabilities[]" value="super_admin_login" <?php echo e(in_array('super_admin_login', old('capabilities', ['super_admin_login'])) ? 'checked' : ''); ?>>
                            <span><strong>super_admin_login</strong> — POST /api/v1/external/login</span>
                        </label>
                        <label class="checkbox-label">
                            <input type="checkbox" name="capabilities[]" value="payment" <?php echo e(in_array('payment', old('capabilities', [])) ? 'checked' : ''); ?>>
                            <span><strong>payment</strong> — POST /api/v1/external/payment</span>
                        </label>
                    </div>
                </div>
                <button type="submit" class="btn btn-purple">Generate Credentials &rarr;</button>
            </form>
        </div>

        
        <div class="card">
            <div class="section-title">Registered Test Systems</div>
            <?php if($systems->isEmpty()): ?>
            <div class="empty-state">No test systems created yet.</div>
            <?php else: ?>
            <table>
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Capabilities</th>
                        <th>Last Used</th>
                        <th>UUID</th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                    <?php $__currentLoopData = $systems; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $sys): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                    <tr>
                        <td><?php echo e($sys->name); ?></td>
                        <td>
                            <?php $__currentLoopData = $sys->capabilities; $__env->addLoop($__currentLoopData); foreach($__currentLoopData as $cap): $__env->incrementLoopIndices(); $loop = $__env->getLastLoop(); ?>
                            <span class="badge-pill badge-purple"><?php echo e($cap); ?></span>
                            <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?>
                        </td>
                        <td><?php echo e($sys->last_used_at?->diffForHumans() ?? '—'); ?></td>
                        <td class="mono"><?php echo e(substr($sys->id, 0, 8)); ?>…</td>
                        <td>
                            <form method="POST" action="<?php echo e(route('testbed.pairing.destroy', $sys->id)); ?>" onsubmit="return confirm('Delete this test system?')">
                                <?php echo csrf_field(); ?>
                                <button type="submit" class="btn btn-red btn-sm">Delete</button>
                            </form>
                        </td>
                    </tr>
                    <?php endforeach; $__env->popLoop(); $loop = $__env->getLastLoop(); ?>
                </tbody>
            </table>
            <?php endif; ?>
        </div>
    </div>

    <script>
        function copyText(elementId, btn) {
            const text = document.getElementById(elementId).textContent.trim();
            navigator.clipboard.writeText(text).then(() => {
                btn.textContent = 'Copied!';
                setTimeout(() => btn.textContent = 'Copy', 2000);
            });
        }
    </script>
</body>

</html><?php /**PATH C:\xampp\htdocs\SuperAdmin\otp_server\resources\views/testbed/system-pairing.blade.php ENDPATH**/ ?>