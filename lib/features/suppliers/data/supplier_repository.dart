import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/currency_config.dart';
import '../../../core/services/activity_log.dart';
import 'supplier_model.dart';
import 'supplier_transaction_model.dart';

/// Suppliers and their cargo/payment history, scoped to the linked business.
///
/// Mirrors [ClientRepository]'s offline contract: writes are NOT awaited
/// (Firestore applies them to the local cache instantly and syncs later),
/// and balances move via WriteBatch + FieldValue.increment rather than
/// runTransaction, which cannot run offline. Increments are commutative, so
/// several devices editing while offline still merge to the right total.
/// Every write carries an [ActivityLog] record; deletes are soft.
class SupplierRepository {
  SupplierRepository(this._db, this.businessId, this._log);

  final FirebaseFirestore _db;
  final String businessId;
  final ActivityLog _log;

  static const _ledger = AppConstants.suppliersCollection;

  CollectionReference<Map<String, dynamic>> get _suppliers => _db
      .collection(AppConstants.businessesCollection)
      .doc(businessId)
      .collection(AppConstants.suppliersCollection);

  DocumentReference<Map<String, dynamic>> _supplierDoc(String id) =>
      _suppliers.doc(id);

  CollectionReference<Map<String, dynamic>> _entries(String supplierId) =>
      _supplierDoc(supplierId).collection(AppConstants.transactionsCollection);

  // --- Suppliers ---

  /// Unordered stream of non-deleted suppliers; the provider sorts
  /// client-side by outstanding amount.
  Stream<List<Supplier>> watchSuppliers() => _suppliers.snapshots().map(
    (snapshot) =>
        snapshot.docs.map(Supplier.fromDoc).where((s) => !s.deleted).toList(),
  );

  /// Emits null once the supplier is gone or soft-deleted.
  Stream<Supplier?> watchSupplier(String id) =>
      _supplierDoc(id).snapshots().map((doc) {
        if (!doc.exists) return null;
        final supplier = Supplier.fromDoc(doc);
        return supplier.deleted ? null : supplier;
      });

  void addSupplier({required String name, String? phone, String? notes}) {
    final data = {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final ref = _suppliers.doc();
    final batch = _db.batch()
      ..set(ref, {
        ...data,
        for (final currency in AppCurrency.values) currency.balanceField: 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    _log.commit(
      batch,
      action: 'party.create',
      ledger: _ledger,
      partyId: ref.id,
      after: data,
    );
  }

  void updateSupplier(
    Supplier old, {
    required String name,
    String? phone,
    String? notes,
  }) {
    final batch = _db.batch()
      ..update(_supplierDoc(old.id), {
        'name': name,
        'phone': (phone == null || phone.isEmpty) ? FieldValue.delete() : phone,
        'notes': (notes == null || notes.isEmpty) ? FieldValue.delete() : notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    _log.commit(
      batch,
      action: 'party.update',
      ledger: _ledger,
      partyId: old.id,
      before: old.toLog(),
      after: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  /// Whether the supplier has any non-deleted history (cache-backed offline).
  Future<bool> hasEntries(String id) async {
    final snapshot = await _entries(id).get();
    return snapshot.docs.any((doc) => doc.data()['deleted'] != true);
  }

  /// Soft delete: the supplier (and its untouched history) stays in
  /// Firestore stamped `deleted`, and disappears from every list and total.
  void deleteSupplier(Supplier supplier) {
    final batch = _db.batch()
      ..update(_supplierDoc(supplier.id), {
        ..._log.deletionStamp,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    _log.commit(
      batch,
      action: 'party.delete',
      ledger: _ledger,
      partyId: supplier.id,
      before: supplier.toLog(),
    );
  }

  // --- Cargo / payment entries ---

  /// Live, non-deleted history, newest first.
  Stream<List<SupplierTransaction>> watchEntries(String supplierId) =>
      _entries(supplierId)
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(SupplierTransaction.fromDoc)
                .where((entry) => !entry.deleted)
                .toList(),
          );

  /// Reads the supplier and its history straight from the server (the same
  /// query as [watchEntries], so it rides the live listener). Completes once
  /// both are current; throws if the server can't be reached.
  Future<void> fetchFromServer(String supplierId) async {
    const server = GetOptions(source: Source.server);
    await Future.wait([
      _entries(supplierId).orderBy('date', descending: true).get(server),
      _supplierDoc(supplierId).get(server),
    ]);
  }

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
    final entryRef = _entries(supplierId).doc();
    final paymentRef = withPayment ? _entries(supplierId).doc() : null;
    batch.set(entryRef, entryData(type));
    if (paymentRef != null) {
      batch.set(paymentRef, entryData(SupplierTxType.payment));
    }
    batch.update(_supplierDoc(supplierId), {
      currency.balanceField: FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _log.commit(
      batch,
      action: 'entry.create',
      ledger: _ledger,
      partyId: supplierId,
      entryId: entryRef.id,
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
    final balanceDelta = currency == old.currency
        ? {currency.balanceField: newSigned - old.signedAmount}
        : {
            old.currency.balanceField: -old.signedAmount,
            currency.balanceField: newSigned,
          };
    batch.update(_supplierDoc(supplierId), {
      for (final e in balanceDelta.entries)
        e.key: FieldValue.increment(e.value),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _log.commit(
      batch,
      action: 'entry.update',
      ledger: _ledger,
      partyId: supplierId,
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
  void deleteEntry({
    required String supplierId,
    required SupplierTransaction entry,
  }) {
    final field = entry.currency.balanceField;
    final batch = _db.batch();
    batch.update(_entries(supplierId).doc(entry.id), _log.deletionStamp);
    batch.update(_supplierDoc(supplierId), {
      field: FieldValue.increment(-entry.signedAmount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _log.commit(
      batch,
      action: 'entry.delete',
      ledger: _ledger,
      partyId: supplierId,
      entryId: entry.id,
      before: entry.toLog(),
      balanceDelta: {field: -entry.signedAmount},
    );
  }
}
