import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/session_providers.dart';
import '../data/client_model.dart';
import '../data/client_repository.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final businessId =
      ref.watch(sessionControllerProvider.select((s) => s.businessId));
  if (businessId == null) {
    throw StateError('clientRepositoryProvider read before business link');
  }
  return ClientRepository(ref.watch(firestoreProvider), businessId);
});

/// Live client list, sorted highest debt first (USD, then SYP as tiebreak).
final clientsStreamProvider = StreamProvider<List<Client>>(
  (ref) => ref.watch(clientRepositoryProvider).watchClients().map((clients) {
    final sorted = [...clients]..sort((a, b) {
        final byUsd = b.balanceUsd.compareTo(a.balanceUsd);
        return byUsd != 0 ? byUsd : b.balanceSyp.compareTo(a.balanceSyp);
      });
    return sorted;
  }),
);

/// Live single client (for the detail header).
final clientStreamProvider = StreamProvider.family<Client?, String>(
  (ref, clientId) => ref.watch(clientRepositoryProvider).watchClient(clientId),
);

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

/// Client list filtered by the search query (name or phone, in-memory —
/// works offline since it filters the already-cached stream).
final filteredClientsProvider = Provider<AsyncValue<List<Client>>>((ref) {
  final clients = ref.watch(clientsStreamProvider);
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return clients;
  return clients.whenData((list) => list
      .where((c) =>
          c.name.contains(query) || (c.phone ?? '').contains(query))
      .toList());
});

typedef DashboardTotals = ({
  double totalUsd,
  double totalSyp,
  int clientCount,
});

/// Dashboard summary derived from the full (unfiltered) client stream.
/// Totals are per currency — never converted or mixed.
final dashboardTotalsProvider = Provider<AsyncValue<DashboardTotals>>((ref) {
  return ref.watch(clientsStreamProvider).whenData((clients) => (
        totalUsd: clients.fold<double>(0, (sum, c) => sum + c.balanceUsd),
        totalSyp: clients.fold<double>(0, (sum, c) => sum + c.balanceSyp),
        clientCount: clients.length,
      ));
});
