import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/ledger_party.dart';
import '../../../core/services/receipt_printer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/balance_row.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/ledger_entry_tile.dart';
import '../../settings/providers/labels_providers.dart';
import '../data/supplier_transaction_model.dart';
import '../providers/supplier_providers.dart';
import 'suppliers_view.dart' show confirmAndDeleteSupplier;

/// Supplier info header + full cargo/payment history + the two record
/// buttons. A positive balance means the business still owes this supplier.
class SupplierDetailScreen extends ConsumerWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(supplierStreamProvider(supplierId));
    final entriesAsync = ref.watch(supplierEntriesStreamProvider(supplierId));
    final labels = ref.watch(labelsProvider);

    return supplierAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (supplier) {
        if (supplier == null) {
          // Deleted (possibly from another device) — leave the screen.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.canPop()) context.pop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        final entries = entriesAsync.value ?? const <SupplierTransaction>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(supplier.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.print_outlined),
                tooltip: AppStrings.printStatement,
                onPressed: () => ReceiptPrinter.printStatement(
                  title: AppStrings.statementOf(labels.supplier),
                  nameLabel: AppStrings.nameField,
                  party: supplier,
                  lines: [
                    for (final entry in entries)
                      (
                        label: entry.type == SupplierTxType.cargo
                            ? labels.cargo
                            : labels.payment,
                        date: entry.date,
                        amount: entry.amount,
                        currency: entry.currency,
                        note: entry.note,
                      ),
                  ],
                  activeCurrencies: {
                    for (final entry in entries) entry.currency,
                  },
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'edit':
                      context.push('/suppliers/$supplierId/edit',
                          extra: supplier);
                    case 'delete':
                      final deleted = await confirmAndDeleteSupplier(
                          context, ref, supplier);
                      if (deleted && context.mounted && context.canPop()) {
                        context.pop();
                      }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(AppStrings.editOf(labels.supplier)),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(AppStrings.deleteOf(labels.supplier)),
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
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                child: Column(
                  children: [
                    Text(AppStrings.balance,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    BalanceRow(
                      balances: supplier.visibleBalances,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (supplier.phone != null) ...[
                      const SizedBox(height: 8),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(supplier.phone!),
                      ),
                    ],
                    if (supplier.notes != null) ...[
                      const SizedBox(height: 4),
                      Text(supplier.notes!,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center),
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
                            backgroundColor: AppTheme.debtColor),
                        onPressed: () => context.push(
                            '/suppliers/$supplierId/tx/new?type=cargo'),
                        icon: const Icon(Icons.add),
                        label: Text(labels.recordCargo),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.paidColor),
                        onPressed: () => context.push(
                            '/suppliers/$supplierId/tx/new?type=payment'),
                        icon: const Icon(Icons.remove),
                        label: Text(labels.recordPayment),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // --- Cargo/payment history, newest first ---
              Expanded(
                child: entriesAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const Center(
                          child: Text(AppStrings.noTransactions));
                    }
                    return ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final isCargo = entry.type == SupplierTxType.cargo;
                        return LedgerEntryTile(
                          label: isCargo ? labels.cargo : labels.payment,
                          increase: isCargo,
                          amount: entry.amount,
                          currency: entry.currency,
                          date: entry.date,
                          note: entry.note,
                          byName: entry.createdByName,
                          onLongPress: () =>
                              _showEntryActions(context, ref, entry),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEntryActions(
      BuildContext context, WidgetRef ref, SupplierTransaction entry) {
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
                context.push('/suppliers/$supplierId/tx/${entry.id}/edit',
                    extra: entry);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
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
                      .read(supplierRepositoryProvider)
                      .deleteEntry(supplierId: supplierId, entry: entry);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
