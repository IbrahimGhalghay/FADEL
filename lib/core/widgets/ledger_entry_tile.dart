import 'package:flutter/material.dart';

import '../constants/currency_config.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'amount_text.dart';

/// One entry in a party's history — a debt or cargo receipt ([increase]
/// true, red) or a payment ([increase] false, green).
class LedgerEntryTile extends StatelessWidget {
  const LedgerEntryTile({
    super.key,
    required this.label,
    required this.increase,
    required this.amount,
    required this.currency,
    required this.date,
    this.note,
    this.byName,
    required this.onLongPress,
  });

  final String label;
  final bool increase;
  final double amount;
  final AppCurrency currency;
  final DateTime date;
  final String? note;

  /// Employee who recorded the entry.
  final String? byName;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = increase ? AppTheme.debtColor : AppTheme.paidColor;
    return ListTile(
      onLongPress: onLongPress,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          // Vertical arrows need no RTL mirroring.
          increase ? Icons.arrow_upward : Icons.arrow_downward,
          color: color,
        ),
      ),
      title: Row(
        children: [
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          const Spacer(),
          AmountText(
            amount,
            currency: currency,
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
                child: Text(Formatters.date(date)),
              ),
              const Spacer(),
              // Under the amount (end/left side in RTL): who recorded it.
              if (byName != null)
                Flexible(
                  child: Text(
                    byName!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
          if (note != null) Text(note!),
        ],
      ),
    );
  }
}
