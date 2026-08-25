import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../clients/screens/clients_view.dart';
import '../../settings/providers/labels_providers.dart';
import '../../suppliers/screens/suppliers_view.dart';

/// Home: the two ledgers side by side — clients who owe the business, and
/// suppliers the business owes. Both tabs stay alive in an [IndexedStack],
/// so search text and scroll position survive switching.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  bool get _onClients => _index == 0;

  @override
  Widget build(BuildContext context) {
    final labels = ref.watch(labelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppStrings.settings,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push(_onClients ? '/clients/new' : '/suppliers/new'),
        icon: Icon(_onClients ? Icons.person_add : Icons.add_business),
        label: Text(_onClients
            ? AppStrings.addClient
            : AppStrings.addOf(labels.supplier)),
      ),
      body: IndexedStack(
        index: _index,
        children: const [ClientsView(), SuppliersView()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: AppStrings.clientsTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping),
            label: labels.suppliers,
          ),
        ],
      ),
    );
  }
}
