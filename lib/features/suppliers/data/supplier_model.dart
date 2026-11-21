import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/currency_config.dart';
import '../../../core/models/ledger_party.dart';

/// A supplier (importer) the business buys cargo from.
class Supplier implements LedgerParty {
  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    required this.balanceUsd,
    required this.balanceSyp,
    this.createdAt,
    this.updatedAt,
    this.deleted = false,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final String? phone;
  @override
  final String? notes;

  /// Independent denormalized running balances, one per currency.
  /// Positive = the business still owes the supplier. Field names match the
  /// client documents so both sides read the same way.
  final double balanceUsd;
  final double balanceSyp;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Soft-deleted: kept (with its history) but hidden everywhere.
  /// Parties are never hard deleted.
  final bool deleted;

  /// This party as this device sees it, for the activity log.
  Map<String, dynamic> toLog() => {
    'name': name,
    'phone': ?phone,
    'notes': ?notes,
    AppCurrency.usd.balanceField: balanceUsd,
    AppCurrency.syp.balanceField: balanceSyp,
  };

  @override
  double balance(AppCurrency currency) =>
      currency == AppCurrency.usd ? balanceUsd : balanceSyp;

  factory Supplier.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Supplier(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      phone: data['phone'] as String?,
      notes: data['notes'] as String?,
      balanceUsd: ((data[AppCurrency.usd.balanceField] as num?) ?? 0)
          .toDouble(),
      balanceSyp: ((data[AppCurrency.syp.balanceField] as num?) ?? 0)
          .toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      deleted: data['deleted'] == true,
    );
  }
}
