import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/session_providers.dart';
import '../constants/app_constants.dart';
import '../constants/app_strings.dart';
import 'sync_service.dart';

/// App-wide messenger so background writes can report back after the
/// screen that started them has closed.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// "version+build" of the running app, resolved once in main().
final appVersionProvider = Provider<String>((ref) => 'unknown');

final activityLogProvider = Provider<ActivityLog>((ref) {
  final businessId = ref.watch(
    sessionControllerProvider.select((s) => s.businessId),
  );
  if (businessId == null) {
    throw StateError('activityLogProvider read before business link');
  }
  return ActivityLog(
    ref.watch(firestoreProvider),
    businessId,
    userName: ref.watch(sessionControllerProvider.select((s) => s.userName)),
    appVersion: ref.watch(appVersionProvider),
    // Once the server has a write, pull everything else that changed too.
    onCommitted: ref.watch(syncServiceProvider).resyncInBackground,
  );
});

/// Append-only audit trail of every ledger write, for diagnosing how a
/// balance got where it is (`businesses/{id}/logs`, read with
/// tool/activity_log.js).
///
/// Each record is written in the SAME batch as the change it describes, so a
/// record exists exactly when the change was applied. It captures what this
/// device believed at the time ([before] may be stale — that is the point),
/// the balance increments it sent, and both the device clock and the server
/// commit time, so time spent queued offline is visible.
///
/// If the server rejects a batch, Firestore rolls the change (and its record)
/// back on every device; the attempt is then logged again on its own with
/// `rejected: true` and the error, and the user is told it didn't stick.
class ActivityLog {
  ActivityLog(
    this._db,
    this.businessId, {
    this.userName,
    required this.appVersion,
    this.onCommitted,
    String Function()? currentUid,
  }) : _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid ?? '');

  final FirebaseFirestore _db;
  final String businessId;
  final String? userName;
  final String appVersion;

  /// Called once the server has accepted a batch (right away online, or
  /// whenever the device reconnects). Used to force a resync, so saving an
  /// entry also brings in what other devices wrote meanwhile.
  final void Function()? onCommitted;
  final String Function() _currentUid;

  /// This device's anonymous uid (one per install).
  String get uid => _currentUid();

  CollectionReference<Map<String, dynamic>> get _logs => _db
      .collection(AppConstants.businessesCollection)
      .doc(businessId)
      .collection(AppConstants.logsCollection);

  /// Adds the record to [batch] and commits it without awaiting, so the UI
  /// never blocks offline.
  ///
  /// [action] is `entry.create|update|delete` or `party.create|update|delete`;
  /// [ledger] is the party collection (`clients` / `suppliers`).
  void commit(
    WriteBatch batch, {
    required String action,
    required String ledger,
    required String partyId,
    String? entryId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    Map<String, num>? balanceDelta,
    Map<String, dynamic>? extra,
  }) {
    final record = <String, dynamic>{
      'action': action,
      'ledger': ledger,
      'partyId': partyId,
      'entryId': ?entryId,
      'before': ?before,
      'after': ?after,
      'balanceDelta': ?balanceDelta,
      ...?extra,
      'uid': uid,
      'userName': ?userName,
      'appVersion': appVersion,
      'deviceTime': Timestamp.now(),
    };
    batch.set(_logs.doc(), {...record, 'at': FieldValue.serverTimestamp()});
    unawaited(
      batch.commit().then(
        (_) => onCommitted?.call(),
        onError: (Object error) {
          unawaited(
            _logs
                .doc()
                .set({
                  ...record,
                  'rejected': true,
                  'error': error is FirebaseException
                      ? '${error.code}: ${error.message}'
                      : '$error',
                  'rejectedDeviceTime': Timestamp.now(),
                  'at': FieldValue.serverTimestamp(),
                })
                .catchError((_) {}),
          );
          scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text(AppStrings.writeRejected)),
          );
        },
      ),
    );
  }

  /// Fields stamped on a soft-deleted entry or party. Nothing is ever hard
  /// deleted: the doc stays (security rules forbid deletes) and readers
  /// filter on `deleted`.
  Map<String, dynamic> get deletionStamp => {
    'deleted': true,
    'deletedAt': FieldValue.serverTimestamp(),
    'deletedBy': uid,
    'deletedByName': ?userName,
  };
}
