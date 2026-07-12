import 'package:cloud_firestore/cloud_firestore.dart';

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
    required this.date,
    this.note,
    required this.createdBy,
    this.createdAt,
  });

  final String id;
  final TxType type;
  final double amount;
  final DateTime date;
  final String? note;
  final String createdBy;
  final DateTime? createdAt;

  /// Effect of this transaction on the client's balance:
  /// debt increases what the client owes, payment decreases it.
  double get signedAmount => type == TxType.debt ? amount : -amount;

  factory ClientTransaction.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ClientTransaction(
      id: doc.id,
      type: TxType.fromName(data['type'] as String?),
      amount: ((data['amount'] as num?) ?? 0).toDouble(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] as String?,
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
