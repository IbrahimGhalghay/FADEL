import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/session_providers.dart';

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(ref.watch(firestoreProvider)),
);

/// Forces every open Firestore listener to catch up with the server.
///
/// Normally listeners stay live on their own, but on a flaky connection the
/// watch stream can go stale without the SDK noticing: this device's own
/// writes still show (they are applied locally) while entries added from
/// other devices never arrive. Restarting the network tears both streams
/// down and re-listens every active query with its resume token, so the
/// server sends exactly what changed since — cheap, and it covers the
/// party list, the open party and its whole history at once.
///
/// Queued offline writes are untouched: they stay in the local queue and
/// are resent when the network comes back up.
class SyncService {
  SyncService(this._db);

  final FirebaseFirestore _db;
  Future<void>? _running;

  /// Restarts the connection; concurrent calls share one restart.
  Future<void> resync() => _running ??= _restart().whenComplete(() {
    _running = null;
  });

  /// [resync] for fire-and-forget callers; errors are irrelevant there
  /// (the SDK keeps retrying on its own).
  void resyncInBackground() => unawaited(resync().catchError((_) {}));

  Future<void> _restart() async {
    await _db.disableNetwork();
    await _db.enableNetwork();
  }

  /// Pull-to-refresh: restarts the connection, then waits until the given
  /// [fetches] come back from the server, so the spinner stops only once
  /// the history on screen is current. Throws if the server can't be
  /// reached within [timeout].
  Future<void> refresh(
    List<Future<void> Function()> fetches, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await resync();
    await Future.wait([for (final fetch in fetches) fetch()]).timeout(timeout);
  }
}
