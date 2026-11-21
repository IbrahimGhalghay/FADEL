import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/currency_config.dart';
import '../../../core/services/activity_log.dart';
import 'transaction_model.dart';

/// CRUD for a client's transactions, keeping the client's denormalized
/// `balance` in sync atomically.
///
/// Balance updates use WriteBatch + FieldValue.increment (NOT runTransaction):
/// increments are commutative and merge correctly server-side even when
/// several offline devices queue changes, and batches — unlike Firestore
/// transactions — work fully offline. Commits are not awaited so the UI
/// never blocks without connectivity. Every batch carries its own
/// [ActivityLog] record, and deletes are soft (the doc is stamped
/// `deleted`, never removed).
class TransactionRepository {
  TransactionRepository(this._db, this.businessId, this._log);

  final FirebaseFirestore _db;
  final String businessId;
  final ActivityLog _log;

  static const _ledger = AppConstants.clientsCollection;

  DocumentReference<Map<String, dynamic>> _clientDoc(String clientId) => _db
      .collection(AppConstants.businessesCollection)
      .doc(businessId)
      .collection(AppConstants.clientsCollection)
      .doc(clientId);

  CollectionReference<Map<String, dynamic>> _transactions(String clientId) =>
      _clientDoc(clientId).collection(AppConstants.transactionsCollection);

  /// Live, non-deleted history, newest first.
  Stream<List<ClientTransaction>> watchTransactions(String clientId) =>
      _transactions(clientId)
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(ClientTransaction.fromDoc)
                .where((tx) => !tx.deleted)
                .toList(),
          );

  /// Reads the client and its history straight from the server (the same
  /// query as [watchTransactions], so it rides the live listener). Completes
  /// once both are current; throws if the server can't be reached.
  Future<void> fetchFromServer(String clientId) async {
    const server = GetOptions(source: Source.server);
    await Future.wait([
      _transactions(clientId).orderBy('date', descending: true).get(server),
      _clientDoc(clientId).get(server),
    ]);
  }

  /// [payDirectly] (debt only): also records a payment for the same amount
  /// in the same atomic batch — the sale and its immediate settlement both
  /// appear in history while the balance nets out unchanged.
  void addTransaction({
    required String clientId,
    required TxType type,
    required double amount,
    required AppCurrency currency,
    required DateTime date,
    String? note,
    required String createdBy,
    String? createdByName,
    bool payDirectly = false,
  }) {
    Map<String, dynamic> txData(TxType t) => {
      'type': t.name,
      'amount': amount,
      'currency': currency.name,
      'date': Timestamp.fromDate(date),
      if (note != null && note.isNotEmpty) 'note': note,
      'createdBy': createdBy,
      'createdByName': ?createdByName,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final withPayment = payDirectly && type == TxType.debt;
    final signed = type == TxType.debt ? amount : -amount;
    final delta = withPayment ? 0 : signed;

    final batch = _db.batch();
    final txRef = _transactions(clientId).doc();
    final paymentRef = withPayment ? _transactions(clientId).doc() : null;
    batch.set(txRef, txData(type));
    if (paymentRef != null) batch.set(paymentRef, txData(TxType.payment));
    batch.update(_clientDoc(clientId), {
      currency.balanceField: FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _log.commit(
      batch,
      action: 'entry.create',
      ledger: _ledger,
      partyId: clientId,
      entryId: txRef.id,
      after: {
        'type': type.name,
        'amount': amount,
        'currency': currency.name,
        'date': Timestamp.fromDate(date),
        if (note != null && note.isNotEmpty) 'note': note,
      },
      balanceDelta: {currency.balanceField: delta},
      extra: {'pairedPaymentId': ?paymentRef?.id},
    );
  }

  void updateTransaction({
    required String clientId,
    required ClientTransaction old,
    required TxType type,
    required double amount,
    required AppCurrency currency,
    required DateTime date,
    String? note,
  }) {
    final newSigned = type == TxType.debt ? amount : -amount;
    final batch = _db.batch();
    batch.update(_transactions(clientId).doc(old.id), {
      'type': type.name,
      'amount': amount,
      'currency': currency.name,
      'date': Timestamp.fromDate(date),
      'note': (note == null || note.isEmpty) ? FieldValue.delete() : note,
    });
    // Currency may have changed: move the amount out of the old currency's
    // balance and into the new one's (same currency = single net increment).
    final balanceDelta = currency == old.currency
        ? {currency.balanceField: newSigned - old.signedAmount}
        : {
            old.currency.balanceField: -old.signedAmount,
            currency.balanceField: newSigned,
          };
    batch.update(_clientDoc(clientId), {
      for (final e in balanceDelta.entries)
        e.key: FieldValue.increment(e.value),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _log.commit(
      batch,
      action: 'entry.update',
      ledger: _ledger,
      partyId: clientId,
      entryId: old.id,
      before: old.toLog(),
      after: {
        'type': type.name,
        'amount': amount,
        'currency': currency.name,
        'date': Timestamp.fromDate(date),
        if (note != null && note.isNotEmpty) 'note': note,
      },
      balanceDelta: balanceDelta,
    );
  }

  /// Soft delete: stamps the entry `deleted` and takes its effect back out
  /// of the balance. The doc itself is kept for the record.
  void deleteTransaction({
    required String clientId,
    required ClientTransaction transaction,
  }) {
    final field = transaction.currency.balanceField;
    final batch = _db.batch();
    batch.update(
      _transactions(clientId).doc(transaction.id),
      _log.deletionStamp,
    );
    batch.update(_clientDoc(clientId), {
      field: FieldValue.increment(-transaction.signedAmount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _log.commit(
      batch,
      action: 'entry.delete',
      ledger: _ledger,
      partyId: clientId,
      entryId: transaction.id,
      before: transaction.toLog(),
      balanceDelta: {field: -transaction.signedAmount},
    );
  }
}
