import 'package:flutter/material.dart';

import '../constants/currency_config.dart';
import '../theme/app_theme.dart';
import 'amount_text.dart';

/// One row of per-currency balances, colour-coded (red = outstanding,
/// green = settled or in credit).
///
/// Two balances hug opposite edges of the row; a single one centres. The
/// list is in RTL display order — the first entry sits on the right.
class BalanceRow extends StatelessWidget {
  const BalanceRow({super.key, required this.balances, this.style});

  final List<(AppCurrency, double)> balances;

  /// Null keeps the ambient [DefaultTextStyle] (used inside summary cards).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: balances.length > 1
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.center,
      children: [
        for (final (index, (currency, value)) in balances.indexed) ...[
          if (index > 0) const SizedBox(width: 16),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AmountText(
                value,
                currency: currency,
                style: style,
                color: value > 0 ? AppTheme.debtColor : AppTheme.paidColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
