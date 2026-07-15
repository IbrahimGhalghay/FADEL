import 'package:intl/intl.dart' as intl;

class Formatters {
  Formatters._();

  /// Gregorian date with Western digits, kept LTR (e.g. 13/07/2026).
  static final intl.DateFormat _date = intl.DateFormat('dd/MM/yyyy', 'en_US');

  static String date(DateTime value) => _date.format(value);
}
