import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fadel_debt_tracker/core/constants/currency_config.dart';
import 'package:fadel_debt_tracker/core/services/activity_log.dart';
import 'package:fadel_debt_tracker/features/clients/data/client_repository.dart';
import 'package:fadel_debt_tracker/features/clients/providers/client_providers.dart';
import 'package:fadel_debt_tracker/features/suppliers/data/supplier_repository.dart';
import 'package:fadel_debt_tracker/features/suppliers/data/supplier_transaction_model.dart';
import 'package:fadel_debt_tracker/features/suppliers/providers/supplier_providers.dart';
import 'package:fadel_debt_tracker/features/transactions/data/transaction_model.dart';
import 'package:fadel_debt_tracker/features/transactions/data/transaction_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end check of soft delete through the real repositories and
/// providers (in-memory Firestore): deleted entries/parties never show, and
/// every balance — per party and the main totals, USD and SYP — counts only
/// non-deleted records.
const _biz = 'F@del';

late FakeFirebaseFirestore db;
late ClientRepository clients;
late TransactionRepository txs;
late SupplierRepository suppliers;

/// Lets the un-awaited batch commits land.
Future<void> settle() => Future<void>.delayed(Duration.zero);

CollectionReference<Map<String, dynamic>> col(String ledger) =>
    db.collection('businesses').doc(_biz).collection(ledger);

Future<String> idOf(String ledger, String name) async =>
    (await col(ledger).where('name', isEqualTo: name).get()).docs.single.id;

ProviderContainer container() {
  final c = ProviderContainer(overrides: [
    clientRepositoryProvider.overrideWithValue(clients),
    supplierRepositoryProvider.overrideWithValue(suppliers),
  ]);
  addTearDown(c.dispose);
  return c;
}

// Riverpod pauses providers nobody listens to, so listen (as a screen
// would) before awaiting the first value.
Future<DashboardTotals> clientTotals() async {
  final c = container()..listen(dashboardTotalsProvider, (_, _) {});
  await c.read(clientsStreamProvider.future);
  return c.read(dashboardTotalsProvider).requireValue;
}

Future<SupplierTotals> supplierTotals() async {
  final c = container()..listen(supplierTotalsProvider, (_, _) {});
  await c.read(suppliersStreamProvider.future);
  return c.read(supplierTotalsProvider).requireValue;
}

/// Balance implied by the VISIBLE history, per currency.
Map<AppCurrency, double> sumOf(Iterable<(AppCurrency, double)> signed) => {
      for (final currency in AppCurrency.values)
        currency: signed
            .where((e) => e.$1 == currency)
            .fold(0.0, (total, e) => total + e.$2),
    };

void main() {
  setUp(() {
    db = FakeFirebaseFirestore();
    final log = ActivityLog(db, _biz,
        userName: 'Tester', appVersion: 'test', currentUid: () => 'uid-1');
    clients = ClientRepository(db, _biz, log);
    txs = TransactionRepository(db, _biz, log);
    suppliers = SupplierRepository(db, _biz, log);
  });

  void addTx(String clientId, TxType type, double amount, AppCurrency currency,
          {bool payDirectly = false}) =>
      txs.addTransaction(
        clientId: clientId,
        type: type,
        amount: amount,
        currency: currency,
        date: DateTime(2026, 10, 1),
        createdBy: 'uid-1',
        payDirectly: payDirectly,
      );

  Future<ClientTransaction> visibleTx(String clientId, double amount,
          {TxType type = TxType.debt}) async =>
      (await txs.watchTransactions(clientId).first)
          .singleWhere((t) => t.amount == amount && t.type == type);

  test('client entries: deleted ones are hidden and excluded from every '
      'balance and the main totals, in USD and SYP', () async {
    clients.addClient(name: 'A');
    clients.addClient(name: 'B');
    await settle();
    final a = await idOf('clients', 'A');
    final b = await idOf('clients', 'B');

    addTx(a, TxType.debt, 170, AppCurrency.usd);
    addTx(a, TxType.debt, 33, AppCurrency.usd);
    addTx(a, TxType.payment, 50, AppCurrency.usd);
    addTx(a, TxType.debt, 100, AppCurrency.usd); // will be edited, then deleted
    addTx(a, TxType.debt, 50000, AppCurrency.syp);
    addTx(a, TxType.debt, 20000, AppCurrency.syp); // will be deleted
    addTx(a, TxType.payment, 5000, AppCurrency.syp); // will be deleted
    addTx(a, TxType.debt, 40, AppCurrency.usd, payDirectly: true);
    addTx(b, TxType.debt, 10, AppCurrency.usd);
    addTx(b, TxType.debt, 7000, AppCurrency.syp);
    await settle();

    // Edit 100 → 120, then delete the edited entry.
    txs.updateTransaction(
      clientId: a,
      old: await visibleTx(a, 100),
      type: TxType.debt,
      amount: 120,
      currency: AppCurrency.usd,
      date: DateTime(2026, 10, 2),
    );
    await settle();
    txs.deleteTransaction(clientId: a, transaction: await visibleTx(a, 120));
    txs.deleteTransaction(clientId: a, transaction: await visibleTx(a, 20000));
    txs.deleteTransaction(
        clientId: a,
        transaction: await visibleTx(a, 5000, type: TxType.payment));
    // Delete only the payment half of the pay-directly pair.
    txs.deleteTransaction(
        clientId: a,
        transaction: await visibleTx(a, 40, type: TxType.payment));
    await settle();

    // History: deleted entries are gone from the list…
    final history = await txs.watchTransactions(a).first;
    expect(history.map((t) => (t.type, t.amount, t.currency)).toSet(), {
      (TxType.debt, 170.0, AppCurrency.usd),
      (TxType.debt, 33.0, AppCurrency.usd),
      (TxType.payment, 50.0, AppCurrency.usd),
      (TxType.debt, 50000.0, AppCurrency.syp),
      (TxType.debt, 40.0, AppCurrency.usd),
    });
    expect(history.any((t) => t.deleted), isFalse);

    // …but still kept in Firestore, stamped.
    final raw = await col('clients').doc(a).collection('transactions').get();
    expect(raw.docs, hasLength(9));
    final deleted = raw.docs.where((d) => d.data()['deleted'] == true).toList();
    expect(deleted, hasLength(4));
    expect(deleted.every((d) => d.data()['deletedBy'] == 'uid-1'), isTrue);

    // Client balance = visible history only, per currency.
    final clientA = (await clients.watchClient(a).first)!;
    final implied = sumOf(history.map((t) => (t.currency, t.signedAmount)));
    expect(clientA.balanceUsd, closeTo(193, 1e-9)); // 170 + 33 − 50 + 40
    expect(clientA.balanceSyp, closeTo(50000, 1e-9));
    expect(clientA.balanceUsd, closeTo(implied[AppCurrency.usd]!, 1e-9));
    expect(clientA.balanceSyp, closeTo(implied[AppCurrency.syp]!, 1e-9));

    // Main totals across clients, both currencies.
    final totals = await clientTotals();
    expect(totals.totalUsd, closeTo(193 + 10, 1e-9));
    expect(totals.totalSyp, closeTo(50000 + 7000, 1e-9));
    expect(totals.clientCount, 2);

    // Deleting a client hides it everywhere and drops it from the totals,
    // without touching its stored history.
    clients.deleteClient((await clients.watchClient(b).first)!);
    await settle();
    expect(await clients.watchClient(b).first, isNull);
    final list = await clients.watchClients().first;
    expect(list.map((c) => c.name), ['A']);
    final after = await clientTotals();
    expect(after.totalUsd, closeTo(193, 1e-9));
    expect(after.totalSyp, closeTo(50000, 1e-9));
    expect(after.clientCount, 1);
    final rawB = await col('clients').doc(b).get();
    expect(rawB.data()!['deleted'], isTrue);
    expect(
        (await col('clients').doc(b).collection('transactions').get()).docs,
        hasLength(2));

    // A deleted client's name can be reused (duplicate guard reads the
    // filtered list), and "has history" ignores deleted entries.
    expect(await clients.hasTransactions(a), isTrue);

    // Every change left an activity-log record.
    final logs = await db
        .collection('businesses')
        .doc(_biz)
        .collection('logs')
        .get();
    // 2 client creates + 10 entry creates + 1 edit + 4 entry deletes
    // + 1 client delete.
    expect(logs.docs, hasLength(18));
  });

  test('hasTransactions is false once every entry is deleted', () async {
    clients.addClient(name: 'C');
    await settle();
    final c = await idOf('clients', 'C');
    addTx(c, TxType.debt, 5, AppCurrency.usd);
    await settle();
    txs.deleteTransaction(clientId: c, transaction: await visibleTx(c, 5));
    await settle();
    expect(await clients.hasTransactions(c), isFalse);
    expect((await clients.watchClient(c).first)!.balanceUsd, 0);
  });

  test('supplier entries: deleted ones are hidden and excluded from every '
      'balance and the main totals, in USD and SYP', () async {
    suppliers.addSupplier(name: 'S1');
    suppliers.addSupplier(name: 'S2');
    await settle();
    final s1 = await idOf('suppliers', 'S1');
    final s2 = await idOf('suppliers', 'S2');

    void addEntry(String id, SupplierTxType type, double amount,
            AppCurrency currency) =>
        suppliers.addEntry(
          supplierId: id,
          type: type,
          amount: amount,
          currency: currency,
          date: DateTime(2026, 10, 1),
          createdBy: 'uid-1',
        );
    Future<SupplierTransaction> visible(String id, double amount) async =>
        (await suppliers.watchEntries(id).first)
            .singleWhere((e) => e.amount == amount);

    addEntry(s1, SupplierTxType.cargo, 600, AppCurrency.usd);
    addEntry(s1, SupplierTxType.cargo, 300, AppCurrency.usd); // deleted
    addEntry(s1, SupplierTxType.payment, 200, AppCurrency.usd);
    addEntry(s1, SupplierTxType.cargo, 900000, AppCurrency.syp);
    addEntry(s1, SupplierTxType.payment, 100000, AppCurrency.syp); // deleted
    addEntry(s2, SupplierTxType.cargo, 75, AppCurrency.usd);
    addEntry(s2, SupplierTxType.cargo, 3000, AppCurrency.syp);
    await settle();

    suppliers.deleteEntry(supplierId: s1, entry: await visible(s1, 300));
    suppliers.deleteEntry(supplierId: s1, entry: await visible(s1, 100000));
    await settle();

    final history = await suppliers.watchEntries(s1).first;
    expect(history.map((e) => e.amount).toSet(), {600.0, 200.0, 900000.0});
    expect(history.any((e) => e.deleted), isFalse);

    final supplier1 = (await suppliers.watchSupplier(s1).first)!;
    final implied = sumOf(history.map((e) => (e.currency, e.signedAmount)));
    expect(supplier1.balanceUsd, closeTo(400, 1e-9)); // 600 − 200
    expect(supplier1.balanceSyp, closeTo(900000, 1e-9));
    expect(supplier1.balanceUsd, closeTo(implied[AppCurrency.usd]!, 1e-9));
    expect(supplier1.balanceSyp, closeTo(implied[AppCurrency.syp]!, 1e-9));

    final totals = await supplierTotals();
    expect(totals.totalUsd, closeTo(400 + 75, 1e-9));
    expect(totals.totalSyp, closeTo(900000 + 3000, 1e-9));

    suppliers.deleteSupplier((await suppliers.watchSupplier(s2).first)!);
    await settle();
    expect(await suppliers.watchSupplier(s2).first, isNull);
    expect((await suppliers.watchSuppliers().first).map((s) => s.name),
        ['S1']);
    final after = await supplierTotals();
    expect(after.totalUsd, closeTo(400, 1e-9));
    expect(after.totalSyp, closeTo(900000, 1e-9));
  });
}
