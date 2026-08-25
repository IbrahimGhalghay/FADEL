import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/currency_config.dart';
import 'supplier_model.dart';
import 'supplier_transaction_model.dart';

/// Suppliers and their cargo/payment history, scoped to the linked business.
///
/// Mirrors [ClientRepository]'s offline contract: writes are NOT awaited
/// (Firestore applies them to the local cache instantly and syncs later),
/// and balances move via WriteBatch + FieldValue.increment rather than
/// runTransaction, which cannot run offline. Increments are commutative, so
/// several devices editing while offline still merge to the right total.
class SupplierRepository {
  SupplierRepository(this._db, this.businessId);

  final FirebaseFirestore _db;
  final String businessId;

  CollectionReference<Map<String, dynamic>> get _suppliers => _db
      .collection(AppConstants.businessesCollection)
      .doc(businessId)
      .collection(AppConstants.suppliersCollection);

  DocumentReference<Map<String, dynamic>> _supplierDoc(String id) =>
      _suppliers.doc(id);

  CollectionReference<Map<String, dynamic>> _entries(String supplierId) =>
      _supplierDoc(supplierId)
          .collection(AppConstants.transactionsCollection);

  // --- Suppliers ---

  /// Unordered stream; the provider sorts client-side by outstanding amount.
  Stream<List<Supplier>> watchSuppliers() => _suppliers
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Supplier.fromDoc).toList());

  Stream<Supplier?> watchSupplier(String id) => _supplierDoc(id)
      .snapshots()
      .map((doc) => doc.exists ? Supplier.fromDoc(doc) : null);

  void addSupplier({required String name, String? phone, String? notes}) {
    unawaited(_suppliers.add({
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      for (final currency in AppCurrency.values) currency.balanceField: 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }));
  }

  void updateSupplier(String id,
      {required String name, String? phone, String? notes}) {
    unawaited(_supplierDoc(id).update({
      'name': name,
      'phone': (phone == null || phone.isEmpty) ? FieldValue.delete() : phone,
      'notes': (notes == null || notes.isEmpty) ? FieldValue.delete() : notes,
      'updatedAt': FieldValue.serverTimestamp(),
    }));
  }

  /// Whether the supplier has any history (cache-backed offline).
  Future<bool> hasEntries(String id) async {
    final snapshot = await _entries(id).limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  /// Deletes the supplier and cascades to its entries (Firestore never
  /// cascades automatically), in chunked batches.
  Future<void> deleteSupplier(String id) async {
    final entries = await _entries(id).get();
    const chunkSize = 450; // stay under Firestore's 500-op batch limit
    for (var i = 0; i < entries.docs.length; i += chunkSize) {
      final batch = _db.batch();
      for (final doc in entries.docs.skip(i).take(chunkSize)) {
        batch.delete(doc.reference);
      }
      unawaited(batch.commit());
    }
    unawaited(_supplierDoc(id).delete());
  }

  // --- Cargo / payment entries ---

  Stream<List<SupplierTransaction>> watchEntries(String supplierId) =>
      _entries(supplierId)
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map(SupplierTransaction.fromDoc).toList());

  /// [payDirectly] (cargo only): also records a payment of the same amount
  /// in the same atomic batch — the shipment and its immediate settlement
  /// both show in history while the balance nets out unchanged.
  void addEntry({
    required String supplierId,
    required SupplierTxType type,
    required double amount,
    required AppCurrency currency,
    required DateTime date,
    String? note,
    required String createdBy,
    String? createdByName,
    bool payDirectly = false,
  }) {
    Map<String, dynamic> entryData(SupplierTxType t) => {
          'type': t.name,
          'amount': amount,
          'currency': currency.name,
          'date': Timestamp.fromDate(date),
          if (note != null && note.isNotEmpty) 'note': note,
          'createdBy': createdBy,
          'createdByName': ?createdByName,
          'createdAt': FieldValue.serverTimestamp(),
        };

    final withPayment = payDirectly && type == SupplierTxType.cargo;
    final signed = type == SupplierTxType.cargo ? amount : -amount;
    final delta = withPayment ? 0 : signed;

    final batch = _db.batch();
    batch.set(_entries(supplierId).doc(), entryData(type));
    if (withPayment) {
      batch.set(
          _entries(supplierId).doc(), entryData(SupplierTxType.payment));
    }
    batch.update(_supplierDoc(supplierId), {
      currency.balanceField: FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    unawaited(batch.commit());
  }

  void updateEntry({
    required String supplierId,
    required SupplierTransaction old,
    required SupplierTxType type,
    required double amount,
    required AppCurrency currency,
    required DateTime date,
    String? note,
  }) {
    final newSigned = type == SupplierTxType.cargo ? amount : -amount;
    final batch = _db.batch();
    batch.update(_entries(supplierId).doc(old.id), {
      'type': type.name,
      'amount': amount,
      'currency': currency.name,
      'date': Timestamp.fromDate(date),
      'note': (note == null || note.isEmpty) ? FieldValue.delete() : note,
    });
    // Currency may have changed: move the amount out of the old currency's
    // balance and into the new one's (same currency = single net increment).
    final balanceUpdate = currency == old.currency
        ? {
            currency.balanceField:
                FieldValue.increment(newSigned - old.signedAmount)
          }
        : {
            old.currency.balanceField: FieldValue.increment(-old.signedAmount),
            currency.balanceField: FieldValue.increment(newSigned),
          };
    batch.update(_supplierDoc(supplierId), {
      ...balanceUpdate,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    unawaited(batch.commit());
  }

  void deleteEntry({
    required String supplierId,
    required SupplierTransaction entry,
  }) {
    final batch = _db.batch();
    batch.delete(_entries(supplierId).doc(entry.id));
    batch.update(_supplierDoc(supplierId), {
      entry.currency.balanceField: FieldValue.increment(-entry.signedAmount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    unawaited(batch.commit());
  }
}
