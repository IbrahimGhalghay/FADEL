import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/ledger_party.dart';
import '../../../core/services/receipt_printer.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/balance_row.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/ledger_entry_tile.dart';
import '../../settings/providers/labels_providers.dart';
import '../../transactions/data/transaction_model.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../providers/client_providers.dart';
import 'clients_view.dart' show confirmAndDeleteClient;

/// Client info header + full transaction history + record debt/payment.
class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientStreamProvider(clientId));
    final txAsync = ref.watch(transactionsStreamProvider(clientId));
    final labels = ref.watch(labelsProvider);

    return clientAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (client) {
        if (client == null) {
          // Client deleted (possibly from another device) — leave the screen.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.canPop()) context.pop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        final transactions = txAsync.value ?? const <ClientTransaction>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(client.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.print_outlined),
                tooltip: AppStrings.printStatement,
                onPressed: () => ReceiptPrinter.printStatement(
                  title: AppStrings.receiptTitle,
                  nameLabel: AppStrings.clientName,
                  party: client,
                  lines: [
                    for (final tx in transactions)
                      (
                        label: tx.type == TxType.debt
                            ? labels.debt
                            : labels.payment,
                        date: tx.date,
                        amount: tx.amount,
                        currency: tx.currency,
                        note: tx.note,
                      ),
                  ],
                  activeCurrencies: {
                    for (final tx in transactions) tx.currency,
                  },
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'edit':
                      context.push('/clients/$clientId/edit', extra: client);
                    case 'delete':
                      final deleted = await confirmAndDeleteClient(
                        context,
                        ref,
                        client,
                      );
                      if (deleted && context.mounted && context.canPop()) {
                        context.pop();
                      }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text(AppStrings.editClient),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text(AppStrings.deleteClient),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // --- Header ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                child: Column(
                  children: [
                    Text(
                      AppStrings.balance,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    BalanceRow(
                      balances: client.visibleBalances,
                      style: Theme.of(context).textTheme.headlineMedium!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (client.phone != null) ...[
                      const SizedBox(height: 8),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(client.phone!),
                      ),
                    ],
                    if (client.notes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        client.notes!,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              // --- Action buttons ---
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.debtColor,
                        ),
                        onPressed: () =>
                            context.push('/clients/$clientId/tx/new?type=debt'),
                        icon: const Icon(Icons.add),
                        label: Text(labels.recordDebt),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.paidColor,
                        ),
                        onPressed: () => context.push(
                          '/clients/$clientId/tx/new?type=payment',
                        ),
                        icon: const Icon(Icons.remove),
                        label: Text(labels.recordPayment),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // --- Transaction history, newest first ---
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _refresh(context, ref),
                  child: txAsync.when(
                    data: (transactions) {
                      if (transactions.isEmpty) {
                        // Scrollable so pull-to-refresh works when empty too.
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 48),
                            Center(child: Text(AppStrings.noTransactions)),
                          ],
                        );
                      }
                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          final isDebt = tx.type == TxType.debt;
                          return LedgerEntryTile(
                            label: isDebt ? labels.debt : labels.payment,
                            increase: isDebt,
                            amount: tx.amount,
                            currency: tx.currency,
                            date: tx.date,
                            note: tx.note,
                            byName: tx.createdByName,
                            onLongPress: () =>
                                _showTransactionActions(context, ref, tx),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Pull-to-refresh: reconnect and wait for this history to come back
  /// from the server.
  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(transactionRepositoryProvider);
    try {
      await ref.read(syncServiceProvider).refresh([
        () => repo.fetchFromServer(clientId),
      ]);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.syncFailed)),
      );
    }
  }

  void _showTransactionActions(
    BuildContext context,
    WidgetRef ref,
    ClientTransaction tx,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text(AppStrings.editTransaction),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/clients/$clientId/tx/${tx.id}/edit', extra: tx);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text(AppStrings.delete),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirmed = await showConfirmDialog(
                  context,
                  title: AppStrings.delete,
                  message: AppStrings.confirmDeleteTransaction,
                );
                if (confirmed) {
                  ref
                      .read(transactionRepositoryProvider)
                      .deleteTransaction(clientId: clientId, transaction: tx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
