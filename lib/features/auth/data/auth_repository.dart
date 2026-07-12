import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_constants.dart';

/// Handles silent anonymous Firebase Auth and business membership.
class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String? get currentUid => _auth.currentUser?.uid;

  /// Signs in anonymously if there is no persisted session yet.
  Future<User> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  /// Checks against the SERVER (not cache) that the business exists.
  /// The app never creates businesses — a typo must fail loudly here.
  Future<bool> businessExists(String businessId) async {
    final doc = await _db
        .collection(AppConstants.businessesCollection)
        .doc(businessId)
        .get(const GetOptions(source: Source.server));
    return doc.exists;
  }

  /// Self-registers this device's anonymous uid as a member of the business.
  Future<void> registerMembership(String businessId, String uid) {
    return _db
        .collection(AppConstants.businessesCollection)
        .doc(businessId)
        .collection(AppConstants.membersCollection)
        .doc(uid)
        .set({'joinedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
}
