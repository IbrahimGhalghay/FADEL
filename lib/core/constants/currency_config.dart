/// Single source of truth for currency display.
/// Change [symbol] / [locale] here if the business currency ever changes.
class CurrencyConfig {
  CurrencyConfig._();

  static const String symbol = r'$';

  /// Locale used for number grouping/decimals (Western digits: 1,250.00).
  static const String locale = 'en_US';

  static const int decimalDigits = 2;
}
