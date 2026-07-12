import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_constants.dart';

/// Stores and verifies the app PIN using OS-encrypted secure storage.
/// The PIN itself is never stored — only a salted SHA-256 hash.
class PinRepository {
  PinRepository(this._storage);

  final FlutterSecureStorage _storage;

  Future<bool> isPinSet() async =>
      await _storage.read(key: AppConstants.pinHashKey) != null;

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    await _storage.write(key: AppConstants.pinSaltKey, value: salt);
    await _storage.write(key: AppConstants.pinHashKey, value: _hash(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: AppConstants.pinSaltKey);
    final storedHash = await _storage.read(key: AppConstants.pinHashKey);
    if (salt == null || storedHash == null) return false;
    return _hash(pin, salt) == storedHash;
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }
}
