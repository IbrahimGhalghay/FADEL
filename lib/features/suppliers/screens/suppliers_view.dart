import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/currency_config.dart';
import '../../../core/widgets/balance_row.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/party_list_tile.dart';
import '../../../core/widgets/summary_card.dart';
import '../../settings/providers/labels_providers.dart';
import '../data/supplier_model.dart';
import '../providers/supplier_providers.dart';

/// Suppliers tab: total still owed to suppliers, search, and the supplier
/// list sorted by largest outstanding amount. The AppBar and the add button
/// live in the shell.
class SuppliersView extends ConsumerWidget {
  const SuppliersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(supplierTotalsProvider);
    final suppliers = ref.watch(filteredSuppliersProvider);
    final hasQuery = ref.watch(supplierSearchQueryProvider).trim().isNotEmpty;
    final labels = ref.watch(labelsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SummaryCard(
            title: AppStrings.totalDue,
            icon: Icons.local_shipping_outlined,
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
            onChanged: ref.read(supplierSearchQueryProvider.notifier).set,
            decoration: const InputDecoration(
              hintText: AppStrings.searchHint,
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: suppliers.when(
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    hasQuery
                        ? AppStrings.noSearchResults
                        : AppStrings.noneYet(labels.supplier),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final supplier = list[index];
                  return PartyListTile(
                    party: supplier,
                    onTap: () => context.push('/suppliers/${supplier.id}'),
                    onLongPress: () =>
                        _showSupplierActions(context, ref, supplier),
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

  void _showSupplierActions(
      BuildContext context, WidgetRef ref, Supplier supplier) {
    final noun = ref.read(labelsProvider).supplier;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(AppStrings.editOf(noun)),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/suppliers/${supplier.id}/edit', extra: supplier);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text(AppStrings.deleteOf(noun)),
              onTap: () async {
                Navigator.pop(sheetContext);
                await confirmAndDeleteSupplier(context, ref, supplier);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared by the list long-press and the supplier-detail menu.
/// Warns when the supplier still has cargo/payment history.
Future<bool> confirmAndDeleteSupplier(
    BuildContext context, WidgetRef ref, Supplier supplier) async {
  final repo = ref.read(supplierRepositoryProvider);
  final noun = ref.read(labelsProvider).supplier;
  final hasHistory = await repo.hasEntries(supplier.id);
  if (!context.mounted) return false;
  final confirmed = await showConfirmDialog(
    context,
    title: AppStrings.deleteOf(noun),
    message: hasHistory
        ? '${AppStrings.confirmDeleteGeneric}\n\n${AppStrings.supplierHasEntriesWarning}'
        : AppStrings.confirmDeleteGeneric,
  );
  if (confirmed) {
    await repo.deleteSupplier(supplier.id);
  }
  return confirmed;
}
