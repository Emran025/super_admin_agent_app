import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../shared/infrastructure/default_sms_app_service.dart';
import '../../shared/theme/spacing_tokens.dart';
import '../../shared/widgets/default_sms_app_banner.dart';
import '../cubit/conversations_cubit.dart';
import '../cubit/conversations_state.dart';
import '../widgets/conversation_list_tile.dart';
import 'compose_page.dart';
import 'thread_page.dart';

/// Compensating SMS inbox UI (not part of agent gateway domains).
class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final _searchController = TextEditingController();
  final _defaultSmsService = const DefaultSmsAppService();
  bool _requestingDefault = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<ConversationsCubit>();
    cubit.load();
    _searchController.addListener(() {
      cubit.setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestDefaultSmsApp() async {
    setState(() => _requestingDefault = true);
    try {
      final result = await _defaultSmsService.requestDefaultSmsApp();
      if (!mounted) return;
      final cubit = context.read<ConversationsCubit>();
      await cubit.refreshDefaultSmsStatus();
      if (result == 'granted') {
        await cubit.load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تعيين التطبيق كتطبيق الرسائل الافتراضي'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _requestingDefault = false);
    }
  }

  Future<void> _requestSmsPermission() async {
    final status = await Permission.sms.request();
    if (!mounted) return;
    if (status.isGranted) {
      await context.read<ConversationsCubit>().load();
    }
  }

  bool _isNotDefault(ConversationsState state) {
    return switch (state) {
      ConversationsLoaded(:final isDefaultSmsApp) => !isDefaultSmsApp,
      ConversationsPermissionDenied(:final isDefaultSmsApp) => !isDefaultSmsApp,
      ConversationsError(:final isDefaultSmsApp) => !isDefaultSmsApp,
      ConversationsLoading(:final isDefaultSmsApp) => !isDefaultSmsApp,
      ConversationsInitial(:final isDefaultSmsApp) => !isDefaultSmsApp,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المحادثات'),
          actions: [
            BlocBuilder<ConversationsCubit, ConversationsState>(
              builder: (context, state) {
                if (!_isNotDefault(state)) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.sms_outlined),
                  tooltip: 'تعيين كتطبيق الرسائل الافتراضي',
                  onPressed: _requestingDefault ? null : _requestDefaultSmsApp,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: () => context.read<ConversationsCubit>().load(),
            ),
          ],
        ),
        body: BlocBuilder<ConversationsCubit, ConversationsState>(
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isNotDefault(state))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SpacingTokens.md,
                      SpacingTokens.sm,
                      SpacingTokens.md,
                      0,
                    ),
                    child: DefaultSmsAppBanner(
                      isLoading: _requestingDefault,
                      onRequestDefault: _requestDefaultSmsApp,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(SpacingTokens.md),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'ابحث عن المحادثات...',
                    leading: const Icon(Icons.search),
                    elevation: WidgetStateProperty.all(0),
                    backgroundColor: WidgetStateProperty.all(
                      cs.surfaceContainerHighest,
                    ),
                  ),
                ),
                Expanded(child: _buildListBody(context, state)),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'chats_compose_fab',
          onPressed: () => Navigator.of(context).push(ComposePage.route()),
          tooltip: 'رسالة جديدة',
          child: const Icon(Icons.edit),
        ),
      ),
    );
  }

  Widget _buildListBody(BuildContext context, ConversationsState state) {
    final cs = Theme.of(context).colorScheme;

    if (state is ConversationsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ConversationsPermissionDenied) {
      return _buildMessagePanel(
        context,
        icon: Icons.sms_failed_outlined,
        title: 'إذن قراءة الرسائل مطلوب',
        subtitle: 'يُرجى السماح بقراءة الرسائل لعرض المحادثات.',
        actionLabel: 'منح الإذن',
        onAction: _requestSmsPermission,
      );
    }

    if (state is ConversationsError) {
      return _buildMessagePanel(
        context,
        icon: Icons.error_outline,
        title: 'تعذّر تحميل المحادثات',
        subtitle: state.message,
        actionLabel: 'إعادة المحاولة',
        onAction: () => context.read<ConversationsCubit>().load(),
      );
    }

    if (state is ConversationsLoaded) {
      final items = state.filtered;
      if (items.isEmpty) {
        return _buildMessagePanel(
          context,
          icon: Icons.chat_bubble_outline,
          title: state.searchQuery.isNotEmpty ? 'لا توجد نتائج' : 'لا توجد محادثات',
          subtitle: state.searchQuery.isNotEmpty
              ? 'جرّب كلمات بحث أخرى.'
              : state.isDefaultSmsApp
                  ? 'ستظهر الرسائل الواردة والصادرة هنا.'
                  : 'عيّن التطبيق كتطبيق الرسائل الافتراضي لعرض سجل الرسائل.',
        );
      }

      return RefreshIndicator(
        onRefresh: () => context.read<ConversationsCubit>().load(),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 72,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
          itemBuilder: (context, index) {
            final conversation = items[index];
            return ConversationListTile(
              conversation: conversation,
              onTap: () {
                Navigator.of(context).push(ThreadPage.route(conversation));
              },
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMessagePanel(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: SpacingTokens.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: SpacingTokens.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: SpacingTokens.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
