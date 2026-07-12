import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import 'transaction_model.dart';

/// CRUD for a client's transactions, keeping the client's denormalized
/// `balance` in sync atomically.
///
/// Balance updates use WriteBatch + FieldValue.increment (NOT runTransaction):
/// increments are commutative and merge correctly server-side even when
/// several offline devices queue changes, and batches — unlike Firestore
/// transactions — work fully offline. Commits are not awaited so the UI
/// never blocks without connectivity.
class TransactionRepository {
  TransactionRepository(this._db, this.businessId);

  final FirebaseFirestore _db;
  final String businessId;

  DocumentReference<Map<String, dynamic>> _clientDoc(String clientId) => _db
      .collection(AppConstants.businessesCollection)
      .doc(businessId)
      .collection(AppConstants.clientsCollection)
      .doc(clientId);

  CollectionReference<Map<String, dynamic>> _transactions(String clientId) =>
      _clientDoc(clientId).collection(AppConstants.transactionsCollection);

  Stream<List<ClientTransaction>> watchTransactions(String clientId) =>
      _transactions(clientId)
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map(ClientTransaction.fromDoc).toList());

  void addTransaction({
    required String clientId,
    required TxType type,
    required double amount,
    required DateTime date,
    String? note,
    required String createdBy,
  }) {
    final delta = type == TxType.debt ? amount : -amount;
    final batch = _db.batch();
    batch.set(_transactions(clientId).doc(), {
      'type': type.name,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      if (note != null && note.isNotEmpty) 'note': note,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_clientDoc(clientId), {
      'balance': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    unawaited(batch.commit());
  }

  void updateTransaction({
    required String clientId,
    required ClientTransaction old,
    required TxType type,
    required double amount,
    required DateTime date,
    String? note,
  }) {
    final newSigned = type == TxType.debt ? amount : -amount;
    final delta = newSigned - old.signedAmount;
    final batch = _db.batch();
    batch.update(_transactions(clientId).doc(old.id), {
      'type': type.name,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': (note == null || note.isEmpty) ? FieldValue.delete() : note,
    });
    batch.update(_clientDoc(clientId), {
      'balance': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    unawaited(batch.commit());
  }

  void deleteTransaction({
    required String clientId,
    required ClientTransaction transaction,
  }) {
    final batch = _db.batch();
    batch.delete(_transactions(clientId).doc(transaction.id));
    batch.update(_clientDoc(clientId), {
      'balance': FieldValue.increment(-transaction.signedAmount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    unawaited(batch.commit());
  }
}
