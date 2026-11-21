import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/activity_log.dart';
import '../../auth/providers/session_providers.dart';
import '../data/transaction_model.dart';
import '../data/transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final businessId =
      ref.watch(sessionControllerProvider.select((s) => s.businessId));
  if (businessId == null) {
    throw StateError('transactionRepositoryProvider read before business link');
  }
  return TransactionRepository(
      ref.watch(firestoreProvider), businessId, ref.watch(activityLogProvider));
});

/// Live transaction history for one client, newest first.
final transactionsStreamProvider =
    StreamProvider.family<List<ClientTransaction>, String>(
  (ref, clientId) =>
      ref.watch(transactionRepositoryProvider).watchTransactions(clientId),
);
