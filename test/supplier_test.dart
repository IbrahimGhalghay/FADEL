import 'package:fadel_debt_tracker/core/constants/currency_config.dart';
import 'package:fadel_debt_tracker/core/models/ledger_party.dart';
import 'package:fadel_debt_tracker/features/settings/providers/labels_providers.dart';
import 'package:fadel_debt_tracker/features/suppliers/data/supplier_model.dart';
import 'package:fadel_debt_tracker/features/suppliers/data/supplier_transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

Supplier _supplier({double usd = 0, double syp = 0}) => Supplier(
      id: 's1',
      name: 'مورّد الشام',
      balanceUsd: usd,
      balanceSyp: syp,
    );

SupplierTransaction _entry(SupplierTxType type, double amount) =>
    SupplierTransaction(
      id: 'e1',
      type: type,
      amount: amount,
      date: DateTime(2026, 8, 25),
      createdBy: 'uid',
    );

void main() {
  group('SupplierTxType', () {
    test('cargo raises what we owe, payment lowers it', () {
      expect(_entry(SupplierTxType.cargo, 500).signedAmount, 500);
      expect(_entry(SupplierTxType.payment, 500).signedAmount, -500);
    });

    test('unknown/missing type falls back to cargo', () {
      expect(SupplierTxType.fromName(null), SupplierTxType.cargo);
      expect(SupplierTxType.fromName('cargo'), SupplierTxType.cargo);
      expect(SupplierTxType.fromName('payment'), SupplierTxType.payment);
      // A client 'debt' doc read by mistake must not become a payment.
      expect(SupplierTxType.fromName('debt'), SupplierTxType.cargo);
    });
  });

  group('Supplier balances', () {
    test('reads the same Firestore fields as clients', () {
      final supplier = _supplier(usd: 1200, syp: 3000000);
      expect(supplier.balance(AppCurrency.usd), 1200);
      expect(supplier.balance(AppCurrency.syp), 3000000);
    });

    test('visible balances are RTL-ordered, SYP first', () {
      final balances = _supplier(usd: 100, syp: 250).visibleBalances;
      expect(balances, [(AppCurrency.syp, 250.0), (AppCurrency.usd, 100.0)]);
    });

    test('drops zero currencies but always shows at least one', () {
      expect(_supplier(syp: 250).visibleBalances, [(AppCurrency.syp, 250.0)]);
      expect(_supplier().visibleBalances, [(AppCurrency.usd, 0.0)]);
    });
  });

  group('AppLabels', () {
    test('supplier captions default to the Arabic built-ins', () {
      const labels = AppLabels();
      expect(labels.suppliers, 'الموردين');
      expect(labels.supplier, 'مورّد');
      expect(labels.cargo, 'بضاعة');
    });

    test('a renamed party propagates, blanks fall back', () {
      final labels =
          AppLabels.fromMap({'suppliers': 'المستوردين', 'supplier': '  '});
      expect(labels.suppliers, 'المستوردين');
      expect(labels.supplier, 'مورّد');
      // Untouched client labels keep their defaults.
      expect(labels.debt, 'دين');
    });

    test('round-trips through the Firestore map', () {
      const labels = AppLabels(supplier: 'مستورد', cargo: 'شحنة');
      expect(AppLabels.fromMap(labels.toMap()).supplier, 'مستورد');
      expect(AppLabels.fromMap(labels.toMap()).cargo, 'شحنة');
    });
  });
}
