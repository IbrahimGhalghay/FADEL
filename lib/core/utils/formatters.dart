import 'package:intl/intl.dart' as intl;

import '../constants/currency_config.dart';

class Formatters {
  Formatters._();

  static final intl.NumberFormat _currency = intl.NumberFormat.currency(
    locale: CurrencyConfig.locale,
    symbol: CurrencyConfig.symbol,
    decimalDigits: CurrencyConfig.decimalDigits,
  );

  /// Gregorian date with Western digits, kept LTR (e.g. 13/07/2026).
  static final intl.DateFormat _date = intl.DateFormat('dd/MM/yyyy', 'en_US');

  static String currency(double value) => _currency.format(value);

  static String date(DateTime value) => _date.format(value);
}
