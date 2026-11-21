import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/currency_config.dart';
import '../../../core/services/activity_log.dart';
import 'client_model.dart';

/// CRUD for clients, scoped to the linked business.
///
/// Writes are NOT awaited: Firestore applies them to the local cache
/// instantly and syncs in the background, so the UI never blocks offline.
/// Every write carries an [ActivityLog] record; deletes are soft.
class ClientRepository {
  ClientRepository(this._db, this.businessId, this._log);

  final FirebaseFirestore _db;
  final String businessId;
  final ActivityLog _log;

  static const _ledger = AppConstants.clientsCollection;

  CollectionReference<Map<String, dynamic>> get _clients => _db
      .collection(AppConstants.businessesCollection)
      .doc(businessId)
      .collection(AppConstants.clientsCollection);

  /// Unordered stream of non-deleted clients; the provider sorts
  /// client-side across both currencies (highest USD debt first, then SYP).
  Stream<List<Client>> watchClients() => _clients.snapshots().map((snapshot) =>
      snapshot.docs.map(Client.fromDoc).where((c) => !c.deleted).toList());

  /// Emits null once the client is gone or soft-deleted.
  Stream<Client?> watchClient(String id) =>
      _clients.doc(id).snapshots().map((doc) {
        if (!doc.exists) return null;
        final client = Client.fromDoc(doc);
        return client.deleted ? null : client;
      });

  void addClient({required String name, String? phone, String? notes}) {
    final data = {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final ref = _clients.doc();
    final batch = _db.batch()
      ..set(ref, {
        ...data,
        for (final currency in AppCurrency.values) currency.balanceField: 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    _log.commit(batch,
        action: 'party.create', ledger: _ledger, partyId: ref.id, after: data);
  }

  void updateClient(Client old,
      {required String name, String? phone, String? notes}) {
    final batch = _db.batch()
      ..update(_clients.doc(old.id), {
        'name': name,
        'phone':
            (phone == null || phone.isEmpty) ? FieldValue.delete() : phone,
        'notes':
            (notes == null || notes.isEmpty) ? FieldValue.delete() : notes,
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

  /// Whether the client has any non-deleted history (cache-backed offline).
  Future<bool> hasTransactions(String id) async {
    final snapshot = await _clients
        .doc(id)
        .collection(AppConstants.transactionsCollection)
        .get();
    return snapshot.docs.any((doc) => doc.data()['deleted'] != true);
  }

  /// Soft delete: the client (and its untouched history) stays in Firestore
  /// stamped `deleted`, and disappears from every list and total.
  void deleteClient(Client client) {
    final batch = _db.batch()
      ..update(_clients.doc(client.id), {
        ..._log.deletionStamp,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    _log.commit(batch,
        action: 'party.delete',
        ledger: _ledger,
        partyId: client.id,
        before: client.toLog());
  }
}
