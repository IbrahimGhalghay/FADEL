import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import 'client_model.dart';

/// CRUD for clients, scoped to the linked business.
///
/// Writes are NOT awaited: Firestore applies them to the local cache
/// instantly and syncs in the background, so the UI never blocks offline.
class ClientRepository {
  ClientRepository(this._db, this.businessId);

  final FirebaseFirestore _db;
  final String businessId;

  CollectionReference<Map<String, dynamic>> get _clients => _db
      .collection(AppConstants.businessesCollection)
      .doc(businessId)
      .collection(AppConstants.clientsCollection);

  Stream<List<Client>> watchClients() =>
      _clients.orderBy('balance', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(Client.fromDoc).toList());

  Stream<Client?> watchClient(String id) => _clients
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? Client.fromDoc(doc) : null);

  void addClient({required String name, String? phone, String? notes}) {
    unawaited(_clients.add({
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'balance': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }));
  }

  void updateClient(String id,
      {required String name, String? phone, String? notes}) {
    unawaited(_clients.doc(id).update({
      'name': name,
      'phone': (phone == null || phone.isEmpty) ? FieldValue.delete() : phone,
      'notes': (notes == null || notes.isEmpty) ? FieldValue.delete() : notes,
      'updatedAt': FieldValue.serverTimestamp(),
    }));
  }

  /// Whether the client has any transaction history (cache-backed offline).
  Future<bool> hasTransactions(String id) async {
    final snapshot = await _clients
        .doc(id)
        .collection(AppConstants.transactionsCollection)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Deletes the client and cascades to its transactions subcollection
  /// (Firestore never cascades automatically). Transaction docs are read
  /// from cache when offline, then deleted in chunked batches.
  Future<void> deleteClient(String id) async {
    final txs = await _clients
        .doc(id)
        .collection(AppConstants.transactionsCollection)
        .get();
    const chunkSize = 450; // stay under Firestore's 500-op batch limit
    for (var i = 0; i < txs.docs.length; i += chunkSize) {
      final batch = _db.batch();
      for (final doc in txs.docs.skip(i).take(chunkSize)) {
        batch.delete(doc.reference);
      }
      unawaited(batch.commit());
    }
    unawaited(_clients.doc(id).delete());
  }
}
