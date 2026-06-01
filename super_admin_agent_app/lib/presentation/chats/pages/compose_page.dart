import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/app_module.dart';
import '../../../domain/user_messaging/entities/user_message_delivery_status.dart';
import '../../../domain/user_messaging/use_cases/send_user_sms_use_case.dart';
import '../../../shared/infrastructure/default_sms_app_service.dart';
import '../../shared/theme/spacing_tokens.dart';
import '../../shared/widgets/default_sms_app_banner.dart';
import '../cubit/conversations_cubit.dart';
class ComposePage extends StatefulWidget {
  const ComposePage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const ComposePage());
  }

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final _phoneController = TextEditingController();
  final _bodyController = TextEditingController();
  final _defaultSmsService = const DefaultSmsAppService();
  bool? _isDefaultSmsApp;
  bool _requestingDefault = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultStatus();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultStatus() async {
    try {
      final isDefault = await _defaultSmsService.isDefaultSmsApp();
      if (mounted) setState(() => _isDefaultSmsApp = isDefault);
    } catch (_) {
      if (mounted) setState(() => _isDefaultSmsApp = false);
    }
  }

  Future<void> _requestDefaultSmsApp() async {
    setState(() => _requestingDefault = true);
    try {
      await _defaultSmsService.requestDefaultSmsApp();
      await _loadDefaultStatus();
    } finally {
      if (mounted) setState(() => _requestingDefault = false);
    }
  }

  Future<void> _send() async {
    final phone = _phoneController.text.trim();
    final body = _bodyController.text.trim();
    if (phone.isEmpty || body.isEmpty) return;
    if (_isDefaultSmsApp != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تعيين التطبيق كتطبيق الرسائل الافتراضي')),
      );
      return;
    }

    setState(() => _sending = true);
    final result = await getIt<SendUserSmsUseCase>().execute(address: phone, body: body);
    if (!mounted) return;
    setState(() => _sending = false);

    if (result.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإرسال: ${result.failure}')),
      );
      return;
    }

    if (result.result?.deliveryStatus == UserMessageDeliveryStatus.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل إرسال الرسالة'), backgroundColor: Colors.red),
      );
      return;
    }

    await context.read<ConversationsCubit>().load();

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال الرسالة'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('رسالة جديدة')),
        body: ListView(
          padding: const EdgeInsets.all(SpacingTokens.md),
          children: [
            if (_isDefaultSmsApp == false)
              DefaultSmsAppBanner(
                isLoading: _requestingDefault,
                onRequestDefault: _requestDefaultSmsApp,
              ),
            if (_isDefaultSmsApp == false) const SizedBox(height: SpacingTokens.md),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                hintText: '+966...',
              ),
            ),
            const SizedBox(height: SpacingTokens.md),
            TextField(
              controller: _bodyController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'نص الرسالة',
              ),
            ),
            const SizedBox(height: SpacingTokens.lg),
            FilledButton.icon(
              onPressed: _sending || _isDefaultSmsApp != true ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }
}
