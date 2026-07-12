import '../constants/app_strings.dart';

class Validators {
  Validators._();

  static String? required(String? value) =>
      (value == null || value.trim().isEmpty) ? AppStrings.requiredField : null;

  static String? positiveAmount(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.requiredField;
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return AppStrings.invalidAmount;
    return null;
  }
}
