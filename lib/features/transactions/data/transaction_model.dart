import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/currency_config.dart';

enum TxType {
  debt,
  payment;

  static TxType fromName(String? name) =>
      name == 'payment' ? TxType.payment : TxType.debt;
}

/// Named ClientTransaction to avoid clashing with Firestore's Transaction.
class ClientTransaction {
  const ClientTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.currency = AppCurrency.usd,
    required this.date,
    this.note,
    required this.createdBy,
    this.createdByName,
    this.createdAt,
    this.deleted = false,
  });

  final String id;
  final TxType type;
  final double amount;
  final AppCurrency currency;
  final DateTime date;
  final String? note;
  final String createdBy;

  /// Full name of the employee who recorded this (denormalized for display).
  final String? createdByName;
  final DateTime? createdAt;

  /// Soft-deleted: kept for the record but hidden and excluded from the
  /// balance. Entries are never hard deleted.
  final bool deleted;

  /// This entry as this device sees it, for the activity log.
  Map<String, dynamic> toLog() => {
    'type': type.name,
    'amount': amount,
    'currency': currency.name,
    'date': Timestamp.fromDate(date),
    'note': ?note,
  };

  /// Effect of this transaction on the client's balance:
  /// debt increases what the client owes, payment decreases it.
  double get signedAmount => type == TxType.debt ? amount : -amount;

  factory ClientTransaction.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ClientTransaction(
      id: doc.id,
      type: TxType.fromName(data['type'] as String?),
      amount: ((data['amount'] as num?) ?? 0).toDouble(),
      currency: AppCurrency.fromName(data['currency'] as String?),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] as String?,
      createdBy: (data['createdBy'] as String?) ?? '',
      createdByName: data['createdByName'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      deleted: data['deleted'] == true,
    );
  }
}
