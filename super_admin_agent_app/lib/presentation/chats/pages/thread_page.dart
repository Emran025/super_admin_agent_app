import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../di/app_module.dart';
import '../../../domain/user_messaging/entities/sms_conversation.dart';
import '../../../domain/user_messaging/entities/sms_thread_message.dart';
import '../../../domain/user_messaging/repositories/user_messaging_repository.dart';
import '../../../shared/infrastructure/default_sms_app_service.dart';
import '../../shared/theme/spacing_tokens.dart';
import '../../shared/widgets/default_sms_app_banner.dart';
import '../cubit/thread_cubit.dart';
import '../cubit/thread_state.dart';
import '../utils/avatar_color.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_composer_bar.dart';

class ThreadPage extends StatefulWidget {
  const ThreadPage({super.key, required this.conversation});

  final SmsConversation conversation;

  static Route<void> route(SmsConversation conversation) {
    return MaterialPageRoute<void>(
      builder: (_) => BlocProvider(
        create: (_) => getIt<ThreadCubit>(param1: conversation)
          ..startWatching()
          ..load(),
        child: ThreadPage(conversation: conversation),
      ),
    );
  }

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  final _scrollController = ScrollController();
  final _defaultSmsService = const DefaultSmsAppService();
  bool _requestingDefault = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _requestDefaultSmsApp() async {
    setState(() => _requestingDefault = true);
    try {
      await _defaultSmsService.requestDefaultSmsApp();
      if (!mounted) return;
      final cubit = context.read<ThreadCubit>();
      await cubit.refreshDefaultSmsStatus();
      await cubit.load();
    } finally {
      if (mounted) setState(() => _requestingDefault = false);
    }
  }

  Future<void> _showFailedOptions(SmsThreadMessage message) async {
    final cubit = context.read<ThreadCubit>();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('إعادة الإرسال'),
              onTap: () => Navigator.pop(ctx, 'retry'),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('نسخ النص'),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
              title: Text('حذف', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'retry':
        final ok = await cubit.retryMessage(message.messageId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ok ? 'تم إرسال الرسالة' : 'فشل إعادة الإرسال'),
              backgroundColor: ok ? const Color(0xFF10B981) : Colors.red,
            ),
          );
        }
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.body));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم نسخ النص')),
          );
        }
      case 'delete':
        await getIt<UserMessagingRepository>().deleteMessage(message.messageId);
        await cubit.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatarColor = avatarColorForKey(widget.conversation.address);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: avatarColor.withValues(alpha: 0.25),
                child: Text(
                  widget.conversation.avatarInitial,
                  style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.conversation.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        body: BlocConsumer<ThreadCubit, ThreadState>(
          listenWhen: (prev, next) => next is ThreadLoaded,
          listener: (_, __) => _scrollToBottom(),
          builder: (context, state) {
            final canSend = state.isDefaultSmsApp;
            final showBanner = !state.isDefaultSmsApp;

            if (state is ThreadError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(state.message, textAlign: TextAlign.center),
                      const SizedBox(height: SpacingTokens.md),
                      FilledButton(
                        onPressed: () => context.read<ThreadCubit>().load(),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is ThreadLoading) {
              return Column(
                children: [
                  if (showBanner)
                    Padding(
                      padding: const EdgeInsets.all(SpacingTokens.sm),
                      child: DefaultSmsAppBanner(
                        isLoading: _requestingDefault,
                        onRequestDefault: _requestDefaultSmsApp,
                      ),
                    ),
                  const Expanded(child: Center(child: CircularProgressIndicator())),
                ],
              );
            }

            if (state is! ThreadLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                if (showBanner)
                  Padding(
                    padding: const EdgeInsets.all(SpacingTokens.sm),
                    child: DefaultSmsAppBanner(
                      isLoading: _requestingDefault,
                      onRequestDefault: _requestDefaultSmsApp,
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => context.read<ThreadCubit>().load(),
                    child: state.messages.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.sizeOf(context).height * 0.3,
                                child: Center(
                                  child: Text(
                                    'لا توجد رسائل في هذه المحادثة',
                                    style: TextStyle(color: cs.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: SpacingTokens.sm),
                            itemCount: state.messages.length,
                            itemBuilder: (context, index) {
                              final message = state.messages[index];
                              return MessageBubble(
                                message: message,
                                onFailedTap: message.isFailed
                                    ? () => _showFailedOptions(message)
                                    : null,
                              );
                            },
                          ),
                  ),
                ),
                if (!canSend)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
                    child: Text(
                      'تعيين التطبيق كتطبيق الرسائل الافتراضي مطلوب للإرسال.',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
                MessageComposerBar(
                  enabled: canSend,
                  isSending: state.isSending,
                  onSend: (text) => context.read<ThreadCubit>().sendText(text),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
