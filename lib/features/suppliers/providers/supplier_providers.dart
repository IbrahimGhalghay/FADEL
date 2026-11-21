import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/activity_log.dart';
import '../../auth/providers/session_providers.dart';
import '../data/supplier_model.dart';
import '../data/supplier_repository.dart';
import '../data/supplier_transaction_model.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  final businessId =
      ref.watch(sessionControllerProvider.select((s) => s.businessId));
  if (businessId == null) {
    throw StateError('supplierRepositoryProvider read before business link');
  }
  return SupplierRepository(
      ref.watch(firestoreProvider), businessId, ref.watch(activityLogProvider));
});

/// Live supplier list, largest outstanding amount first (USD, then SYP).
final suppliersStreamProvider = StreamProvider<List<Supplier>>(
  (ref) =>
      ref.watch(supplierRepositoryProvider).watchSuppliers().map((suppliers) {
    final sorted = [...suppliers]..sort((a, b) {
        final byUsd = b.balanceUsd.compareTo(a.balanceUsd);
        return byUsd != 0 ? byUsd : b.balanceSyp.compareTo(a.balanceSyp);
      });
    return sorted;
  }),
);

/// Live single supplier (for the detail header).
final supplierStreamProvider = StreamProvider.family<Supplier?, String>(
  (ref, supplierId) =>
      ref.watch(supplierRepositoryProvider).watchSupplier(supplierId),
);

/// Live cargo/payment history for one supplier, newest first.
final supplierEntriesStreamProvider =
    StreamProvider.family<List<SupplierTransaction>, String>(
  (ref, supplierId) =>
      ref.watch(supplierRepositoryProvider).watchEntries(supplierId),
);

/// Search text for the suppliers tab, kept separate from the clients tab
/// so switching tabs doesn't carry a query across.
final supplierSearchQueryProvider =
    NotifierProvider<SupplierSearchQueryNotifier, String>(
        SupplierSearchQueryNotifier.new);

class SupplierSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

/// Supplier list filtered by name or phone (in-memory, so it works offline).
final filteredSuppliersProvider = Provider<AsyncValue<List<Supplier>>>((ref) {
  final suppliers = ref.watch(suppliersStreamProvider);
  final query = ref.watch(supplierSearchQueryProvider).trim();
  if (query.isEmpty) return suppliers;
  return suppliers.whenData((list) => list
      .where((s) => s.name.contains(query) || (s.phone ?? '').contains(query))
      .toList());
});

typedef SupplierTotals = ({double totalUsd, double totalSyp});

/// Total still owed to all suppliers, per currency — never converted.
final supplierTotalsProvider = Provider<AsyncValue<SupplierTotals>>((ref) {
  return ref.watch(suppliersStreamProvider).whenData((suppliers) => (
        totalUsd: suppliers.fold<double>(0, (sum, s) => sum + s.balanceUsd),
        totalSyp: suppliers.fold<double>(0, (sum, s) => sum + s.balanceSyp),
      ));
});
