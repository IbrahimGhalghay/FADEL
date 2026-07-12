import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/amount_text.dart';
import '../data/transaction_model.dart';

class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    super.key,
    required this.transaction,
    required this.onLongPress,
  });

  final ClientTransaction transaction;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDebt = transaction.type == TxType.debt;
    final color = isDebt ? AppTheme.debtColor : AppTheme.paidColor;
    return ListTile(
      onLongPress: onLongPress,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          // Vertical arrows need no RTL mirroring.
          isDebt ? Icons.arrow_upward : Icons.arrow_downward,
          color: color,
        ),
      ),
      title: Row(
        children: [
          Text(
            isDebt ? AppStrings.debt : AppStrings.payment,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          AmountText(
            transaction.amount,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            color: color,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(Formatters.date(transaction.date),
                textAlign: TextAlign.end),
          ),
          if (transaction.note != null) Text(transaction.note!),
        ],
      ),
    );
  }
}
