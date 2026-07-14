import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../data/auth_repository.dart';
import '../data/pin_repository.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(FirebaseAuth.instance, ref.watch(firestoreProvider)),
);

final pinRepositoryProvider = Provider<PinRepository>(
  (ref) => PinRepository(ref.watch(secureStorageProvider)),
);

enum SessionStatus {
  loading,
  needsBusinessSetup,
  needsName,
  needsPinSetup,
  locked,
  unlocked,
}

class SessionState {
  const SessionState({required this.status, this.businessId, this.userName});

  final SessionStatus status;
  final String? businessId;

  /// Full name of this device's user; stamped on transactions they record.
  final String? userName;

  SessionState copyWith(
          {SessionStatus? status, String? businessId, String? userName}) =>
      SessionState(
        status: status ?? this.status,
        businessId: businessId ?? this.businessId,
        userName: userName ?? this.userName,
      );
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  DateTime? _backgroundedAt;

  @override
  SessionState build() {
    _init();
    return const SessionState(status: SessionStatus.loading);
  }

  Future<void> _init() async {
    final storage = ref.read(secureStorageProvider);
    final businessId = await storage.read(key: AppConstants.businessIdKey);
    final userName = await storage.read(key: AppConstants.userNameKey);
    final pinSet = await ref.read(pinRepositoryProvider).isPinSet();

    if (businessId == null) {
      state = const SessionState(status: SessionStatus.needsBusinessSetup);
      return;
    }

    // Silent re-sign-in in case the persisted anonymous session was lost.
    // Never block startup on it — the app must open offline.
    unawaited(_silentSignIn());

    // Devices linked before the name feature existed land on the name step.
    final status = userName == null
        ? SessionStatus.needsName
        : pinSet
            ? SessionStatus.locked
            : SessionStatus.needsPinSetup;
    state = SessionState(
        status: status, businessId: businessId, userName: userName);
  }

  Future<void> _silentSignIn() async {
    try {
      await ref.read(authRepositoryProvider).ensureSignedIn();
    } catch (_) {
      // Offline or transient auth failure — Firebase retries on next launch.
    }
  }

  /// Joins an existing business. Returns an error message, or null on success.
  /// The app NEVER creates a business — unknown IDs are rejected.
  Future<String?> joinBusiness(String businessId, {required String name}) async {
    final auth = ref.read(authRepositoryProvider);
    try {
      final user = await auth.ensureSignedIn();
      final exists = await auth.businessExists(businessId);
      if (!exists) return AppStrings.businessNotFound;
      await auth.registerMembership(businessId, user.uid, displayName: name);
      final storage = ref.read(secureStorageProvider);
      await storage.write(key: AppConstants.businessIdKey, value: businessId);
      await storage.write(key: AppConstants.userNameKey, value: name);
      state = SessionState(
        status: SessionStatus.needsPinSetup,
        businessId: businessId,
        userName: name,
      );
      return null;
    } catch (_) {
      return AppStrings.connectionError;
    }
  }

  /// Sets the user's full name (for devices linked before this feature,
  /// or future profile edits). Also mirrors it onto the membership doc.
  Future<void> setName(String name) async {
    await ref
        .read(secureStorageProvider)
        .write(key: AppConstants.userNameKey, value: name);
    final auth = ref.read(authRepositoryProvider);
    final businessId = state.businessId;
    final uid = auth.currentUid;
    if (businessId != null && uid != null) {
      unawaited(auth
          .registerMembership(businessId, uid, displayName: name)
          .catchError((_) {}));
    }
    final pinSet = await ref.read(pinRepositoryProvider).isPinSet();
    state = state.copyWith(
      status: pinSet ? SessionStatus.locked : SessionStatus.needsPinSetup,
      userName: name,
    );
  }

  Future<void> setPin(String pin) async {
    await ref.read(pinRepositoryProvider).setPin(pin);
    state = state.copyWith(status: SessionStatus.unlocked);
  }

  Future<bool> unlock(String pin) async {
    final ok = await ref.read(pinRepositoryProvider).verifyPin(pin);
    if (ok) state = state.copyWith(status: SessionStatus.unlocked);
    return ok;
  }

  void lock() {
    if (state.status == SessionStatus.unlocked) {
      state = state.copyWith(status: SessionStatus.locked);
    }
  }

  // --- Auto-lock on background timeout ---

  void onAppBackgrounded() => _backgroundedAt = DateTime.now();

  void onAppResumed() {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) return;
    final timeout = ref.read(lockTimeoutProvider);
    if (DateTime.now().difference(backgroundedAt) >= timeout) lock();
  }
}

/// Configurable auto-lock timeout (persisted; default 2 minutes).
final lockTimeoutProvider =
    NotifierProvider<LockTimeoutController, Duration>(LockTimeoutController.new);

class LockTimeoutController extends Notifier<Duration> {
  @override
  Duration build() {
    _load();
    return AppConstants.defaultLockTimeout;
  }

  Future<void> _load() async {
    final raw = await ref
        .read(secureStorageProvider)
        .read(key: AppConstants.lockTimeoutSecondsKey);
    final seconds = int.tryParse(raw ?? '');
    if (seconds != null) state = Duration(seconds: seconds);
  }

  Future<void> set(Duration timeout) async {
    state = timeout;
    await ref.read(secureStorageProvider).write(
          key: AppConstants.lockTimeoutSecondsKey,
          value: timeout.inSeconds.toString(),
        );
  }
}
