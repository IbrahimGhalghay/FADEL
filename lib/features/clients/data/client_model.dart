import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/currency_config.dart';
import '../../../core/models/ledger_party.dart';

class Client implements LedgerParty {
  const Client({
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
  /// Positive = client owes the business. USD lives in the original
  /// `balance` field so data from before multi-currency stays valid.
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

  factory Client.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Client(
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
