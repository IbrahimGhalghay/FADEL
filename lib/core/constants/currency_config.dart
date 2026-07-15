import 'package:intl/intl.dart' as intl;

/// The currencies the business tracks. Each client keeps an independent
/// running balance per currency — amounts are never converted between them.
///
/// To add another currency: add an enum value, its symbol/format below, and
/// a Firestore balance field name in [balanceField].
enum AppCurrency {
  usd,
  syp;

  /// Missing/unknown currency on old documents means USD (the original
  /// single currency of the app).
  static AppCurrency fromName(String? name) =>
      name == 'syp' ? AppCurrency.syp : AppCurrency.usd;
}

extension AppCurrencyX on AppCurrency {
  String get symbol => switch (this) {
        AppCurrency.usd => r'$',
        AppCurrency.syp => 'ل.س',
      };

  /// Firestore field on the client doc holding this currency's balance.
  /// USD keeps the original `balance` field so pre-currency data stays valid.
  String get balanceField => switch (this) {
        AppCurrency.usd => 'balance',
        AppCurrency.syp => 'balanceSyp',
      };

  static final intl.NumberFormat _usd = intl.NumberFormat.currency(
      locale: 'en_US', symbol: r'$', decimalDigits: 2);

  // SYP amounts are typically whole numbers; show decimals only when present.
  static final intl.NumberFormat _syp = intl.NumberFormat('#,##0.##', 'en_US');

  String format(double value) => switch (this) {
        AppCurrency.usd => _usd.format(value),
        AppCurrency.syp => '${_syp.format(value)} ل.س',
      };
}
