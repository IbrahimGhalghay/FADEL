class AppConstants {
  AppConstants._();

  static const int pinMinLength = 4;
  static const int pinMaxLength = 6;

  /// Default auto-lock timeout after the app is backgrounded.
  static const Duration defaultLockTimeout = Duration(minutes: 2);

  /// Selectable auto-lock timeouts in Settings.
  static const List<Duration> lockTimeoutOptions = [
    Duration.zero, // lock immediately
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];

  // Secure-storage keys
  static const String businessIdKey = 'business_id';
  static const String userNameKey = 'user_name';
  static const String pinHashKey = 'pin_hash';
  static const String pinSaltKey = 'pin_salt';
  static const String lockTimeoutSecondsKey = 'lock_timeout_seconds';

  // Firestore collection names
  static const String businessesCollection = 'businesses';
  static const String membersCollection = 'members';
  static const String clientsCollection = 'clients';
  static const String suppliersCollection = 'suppliers';
  static const String transactionsCollection = 'transactions';
}
