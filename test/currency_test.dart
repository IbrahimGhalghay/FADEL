import 'package:fadel_debt_tracker/core/constants/currency_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppCurrency', () {
    test('formats USD with symbol and two decimals', () {
      expect(AppCurrency.usd.format(1250), r'$1,250.00');
      expect(AppCurrency.usd.format(0), r'$0.00');
    });

    test('formats SYP with grouping and trailing symbol', () {
      expect(AppCurrency.syp.format(50000), '50,000 ل.س');
      expect(AppCurrency.syp.format(1250.5), '1,250.5 ل.س');
    });

    test('missing currency name defaults to USD (legacy docs)', () {
      expect(AppCurrency.fromName(null), AppCurrency.usd);
      expect(AppCurrency.fromName('syp'), AppCurrency.syp);
      expect(AppCurrency.fromName('usd'), AppCurrency.usd);
    });

    test('balance fields stay backward compatible', () {
      expect(AppCurrency.usd.balanceField, 'balance');
      expect(AppCurrency.syp.balanceField, 'balanceSyp');
    });
  });
}
