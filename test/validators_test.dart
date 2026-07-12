import 'package:fadel_debt_tracker/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('required rejects empty and accepts text', () {
      expect(Validators.required(null), isNotNull);
      expect(Validators.required('  '), isNotNull);
      expect(Validators.required('أحمد'), isNull);
    });

    test('positiveAmount rejects zero, negative, and junk', () {
      expect(Validators.positiveAmount(null), isNotNull);
      expect(Validators.positiveAmount(''), isNotNull);
      expect(Validators.positiveAmount('0'), isNotNull);
      expect(Validators.positiveAmount('-5'), isNotNull);
      expect(Validators.positiveAmount('abc'), isNotNull);
      expect(Validators.positiveAmount('120.50'), isNull);
    });
  });
}
