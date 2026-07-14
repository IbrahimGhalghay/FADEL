import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/amount_text.dart';
import '../../settings/providers/labels_providers.dart';
import '../data/transaction_model.dart';

class TransactionListTile extends ConsumerWidget {
  const TransactionListTile({
    super.key,
    required this.transaction,
    required this.onLongPress,
  });

  final ClientTransaction transaction;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(labelsProvider);
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
            isDebt ? labels.debt : labels.payment,
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
          Row(
            children: [
              // Under the type label (start/right side in RTL): the date.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(Formatters.date(transaction.date)),
              ),
              const Spacer(),
              // Under the amount (end/left side in RTL): who recorded it.
              if (transaction.createdByName != null)
                Flexible(
                  child: Text(
                    transaction.createdByName!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
          if (transaction.note != null) Text(transaction.note!),
        ],
      ),
    );
  }
}
