import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/currency_config.dart';

class Client {
  const Client({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    required this.balanceUsd,
    required this.balanceSyp,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? notes;

  /// Independent denormalized running balances, one per currency.
  /// Positive = client owes the business. USD lives in the original
  /// `balance` field so data from before multi-currency stays valid.
  final double balanceUsd;
  final double balanceSyp;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double balance(AppCurrency currency) =>
      currency == AppCurrency.usd ? balanceUsd : balanceSyp;

  /// True when the client owes money in any currency.
  bool get owesAnything => balanceUsd > 0 || balanceSyp > 0;

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
    );
  }
}
