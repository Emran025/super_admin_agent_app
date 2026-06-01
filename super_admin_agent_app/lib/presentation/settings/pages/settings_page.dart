import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../shared/infrastructure/default_sms_app_service.dart';
import '../../shared/theme/spacing_tokens.dart';
import '../../shared/widgets/default_sms_app_banner.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _defaultSmsService = const DefaultSmsAppService();
  bool? _isDefaultSmsApp;
  bool _requestingDefault = false;
  Map<Permission, PermissionStatus> _permissions = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final isDefault = await _defaultSmsService.isDefaultSmsApp();
      if (mounted) setState(() => _isDefaultSmsApp = isDefault);
    } catch (_) {
      if (mounted) setState(() => _isDefaultSmsApp = false);
    }

    final perms = await Future.wait([
      Permission.sms.status,
      Permission.phone.status,
      Permission.contacts.status,
      Permission.notification.status,
    ]);
    if (mounted) {
      setState(() {
        _permissions = {
          Permission.sms: perms[0],
          Permission.phone: perms[1],
          Permission.contacts: perms[2],
          Permission.notification: perms[3],
        };
      });
    }
  }

  Future<void> _requestDefaultSmsApp() async {
    setState(() => _requestingDefault = true);
    try {
      final result = await _defaultSmsService.requestDefaultSmsApp();
      await _refresh();
      if (!mounted) return;
      if (result == 'granted') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تعيين التطبيق كتطبيق الرسائل الافتراضي'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requestingDefault = false);
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    await permission.request();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعدادات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(SpacingTokens.md),
          children: [
            Text(
              'الرسائل القصيرة',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            if (_isDefaultSmsApp == false)
              DefaultSmsAppBanner(
                isLoading: _requestingDefault,
                onRequestDefault: _requestDefaultSmsApp,
              )
            else if (_isDefaultSmsApp == true)
              ListTile(
                leading: Icon(Icons.check_circle, color: cs.primary),
                title: const Text('تطبيق الرسائل الافتراضي'),
                subtitle: const Text('هذا التطبيق هو تطبيق الرسائل الافتراضي على الجهاز.'),
              ),
            const SizedBox(height: SpacingTokens.lg),
            Text(
              'الأذونات',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            ..._permissions.entries.map((e) {
              final granted = e.value.isGranted;
              return ListTile(
                title: Text(_permissionLabel(e.key)),
                subtitle: Text(granted ? 'مُفعَّل' : 'غير مُفعَّل — اضغط للطلب'),
                trailing: Icon(
                  granted ? Icons.check_circle : Icons.error_outline,
                  color: granted ? cs.primary : cs.error,
                ),
                onTap: granted ? null : () => _requestPermission(e.key),
              );
            }),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('إعدادات التطبيق في النظام'),
              subtitle: const Text('فتح إعدادات الأذونات المتقدمة'),
              onTap: openAppSettings,
            ),
            const SizedBox(height: SpacingTokens.lg),
            Text(
              'حول التطبيق',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            const ListTile(
              title: Text('وكيل Super Admin'),
              subtitle: Text(
                'وكيل بوابة موثوق (OTP، 2FA، مراقبة المدفوعات) مع واجهة رسائل '
                'تعويضية عند تعيينه كتطبيق الرسائل الافتراضي.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _permissionLabel(Permission p) {
    return switch (p) {
      Permission.sms => 'قراءة وإرسال الرسائل',
      Permission.phone => 'حالة الهاتف',
      Permission.contacts => 'جهات الاتصال',
      Permission.notification => 'الإشعارات',
      _ => p.toString(),
    };
  }
}
