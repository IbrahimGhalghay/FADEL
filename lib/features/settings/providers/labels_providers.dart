import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../auth/providers/session_providers.dart';

/// Business-wide customizable UI captions, live-synced across all devices
/// via the `labels` map on the business document. Empty/missing values fall
/// back to the built-in defaults.
class AppLabels {
  const AppLabels({
    this.recordDebt = AppStrings.recordDebt,
    this.recordPayment = AppStrings.recordPayment,
    this.debt = AppStrings.debt,
    this.payment = AppStrings.payment,
    this.suppliers = AppStrings.suppliers,
    this.supplier = AppStrings.supplier,
    this.recordCargo = AppStrings.recordCargo,
    this.cargo = AppStrings.cargo,
  });

  final String recordDebt;
  final String recordPayment;
  final String debt;
  final String payment;

  /// Section name (plural, definite) — e.g. 'الموردين' or 'المستوردين'.
  final String suppliers;

  /// Same party, singular and indefinite — composed into captions like
  /// 'إضافة مورّد' and 'حذف مورّد'.
  final String supplier;
  final String recordCargo;
  final String cargo;

  factory AppLabels.fromMap(Map<String, dynamic> map) {
    String pick(String key, String fallback) {
      final value = map[key];
      return (value is String && value.trim().isNotEmpty) ? value : fallback;
    }

    return AppLabels(
      recordDebt: pick('recordDebt', AppStrings.recordDebt),
      recordPayment: pick('recordPayment', AppStrings.recordPayment),
      debt: pick('debt', AppStrings.debt),
      payment: pick('payment', AppStrings.payment),
      suppliers: pick('suppliers', AppStrings.suppliers),
      supplier: pick('supplier', AppStrings.supplier),
      recordCargo: pick('recordCargo', AppStrings.recordCargo),
      cargo: pick('cargo', AppStrings.cargo),
    );
  }

  Map<String, String> toMap() => {
        'recordDebt': recordDebt,
        'recordPayment': recordPayment,
        'debt': debt,
        'payment': payment,
        'suppliers': suppliers,
        'supplier': supplier,
        'recordCargo': recordCargo,
        'cargo': cargo,
      };
}

final _labelsStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final businessId =
      ref.watch(sessionControllerProvider.select((s) => s.businessId));
  if (businessId == null) return Stream.value(const {});
  return ref.watch(authRepositoryProvider).watchBusinessLabels(businessId);
});

/// Always resolves — defaults while loading or when nothing is customized.
final labelsProvider = Provider<AppLabels>((ref) {
  final raw = ref.watch(_labelsStreamProvider).value;
  return raw == null ? const AppLabels() : AppLabels.fromMap(raw);
});
