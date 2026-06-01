import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../di/app_module.dart';
import '../chats/cubit/conversations_cubit.dart';
import '../chats/pages/chats_page.dart';
import '../dashboard/pages/dashboard_page.dart';
import '../settings/pages/settings_page.dart';

/// Root shell after pairing: Chats (user SMS) + Operations (agent) + Settings.
class AgentShellPage extends StatefulWidget {
  const AgentShellPage({super.key});

  @override
  State<AgentShellPage> createState() => _AgentShellPageState();
}

class _AgentShellPageState extends State<AgentShellPage> {
  int _selectedIndex = 1; // Operations tab default (existing dashboard focus)

  static const _tabs = <Widget>[
    ChatsPage(),
    DashboardPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ConversationsCubit>()..startWatching(),
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _tabs,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'المحادثات',
            ),
            NavigationDestination(
              icon: Icon(Icons.hub_outlined),
              selectedIcon: Icon(Icons.hub),
              label: 'العمليات',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}
