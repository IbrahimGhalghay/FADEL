import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/currency_config.dart';
import '../../../core/widgets/balance_row.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/party_list_tile.dart';
import '../../../core/widgets/summary_card.dart';
import '../data/client_model.dart';
import '../providers/client_providers.dart';

/// Clients tab: total owed to the business, search, and the client list
/// sorted by highest debt. The AppBar and the add button live in the shell.
class ClientsView extends ConsumerWidget {
  const ClientsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(dashboardTotalsProvider);
    final clients = ref.watch(filteredClientsProvider);
    final hasQuery = ref.watch(searchQueryProvider).trim().isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SummaryCard(
            title: AppStrings.totalOwed,
            icon: Icons.account_balance_wallet_outlined,
            child: totals.when(
              // RTL row: SYP on the right, USD on the left.
              data: (t) => BalanceRow(balances: [
                if (t.totalSyp != 0) (AppCurrency.syp, t.totalSyp),
                (AppCurrency.usd, t.totalUsd),
              ]),
              loading: () => const Text('...'),
              error: (_, _) => const Text('—'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: ref.read(searchQueryProvider.notifier).set,
            decoration: const InputDecoration(
              hintText: AppStrings.searchHint,
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: clients.when(
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    hasQuery
                        ? AppStrings.noSearchResults
                        : AppStrings.noClients,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final client = list[index];
                  return PartyListTile(
                    party: client,
                    onTap: () => context.push('/clients/${client.id}'),
                    onLongPress: () => _showClientActions(context, ref, client),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
        ),
      ],
    );
  }

  void _showClientActions(BuildContext context, WidgetRef ref, Client client) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text(AppStrings.editClient),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/clients/${client.id}/edit', extra: client);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: const Text(AppStrings.deleteClient),
              onTap: () async {
                Navigator.pop(sheetContext);
                await confirmAndDeleteClient(context, ref, client);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared by the list long-press and the client-detail menu.
/// Warns when the client still has transaction history.
Future<bool> confirmAndDeleteClient(
    BuildContext context, WidgetRef ref, Client client) async {
  final repo = ref.read(clientRepositoryProvider);
  final hasHistory = await repo.hasTransactions(client.id);
  if (!context.mounted) return false;
  final confirmed = await showConfirmDialog(
    context,
    title: AppStrings.deleteClient,
    message: hasHistory
        ? '${AppStrings.confirmDeleteClient}\n\n${AppStrings.clientHasTransactionsWarning}'
        : AppStrings.confirmDeleteClient,
  );
  if (confirmed) {
    await repo.deleteClient(client.id);
  }
  return confirmed;
}
