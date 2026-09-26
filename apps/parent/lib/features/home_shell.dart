import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../l10n/l10n.dart';
import 'apps_page.dart';
import 'children_page.dart';
import 'devices_page.dart';
import 'today_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titles = [
      l10n.tabToday,
      l10n.tabChildren,
      l10n.tabGames,
      l10n.tabComputers,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          PopupMenuButton<void>(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => ref.read(authRepositoryProvider).signOut(),
                child: Text(l10n.signOut),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          TodayPage(),
          ChildrenPage(),
          AppsPage(),
          DevicesPage(),
        ],
      ),
      floatingActionButton: switch (_index) {
        1 => FloatingActionButton.extended(
          icon: const Icon(Icons.person_add),
          label: Text(l10n.addChild),
          onPressed: () => openChildEditor(context),
        ),
        2 => FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: Text(l10n.addGame),
          onPressed: () => openAppEditor(context),
        ),
        3 => FloatingActionButton.extended(
          icon: const Icon(Icons.link),
          label: Text(l10n.pairComputer),
          onPressed: () => showPairDialog(context),
        ),
        _ => null,
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today),
            label: l10n.tabToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people),
            label: l10n.tabChildren,
          ),
          NavigationDestination(
            icon: const Icon(Icons.sports_esports),
            label: l10n.tabGames,
          ),
          NavigationDestination(
            icon: const Icon(Icons.computer),
            label: l10n.tabComputers,
          ),
        ],
      ),
    );
  }
}
