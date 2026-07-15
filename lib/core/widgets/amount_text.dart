import 'package:flutter/material.dart';

import '../constants/currency_config.dart';

/// Renders a currency amount with LTR direction forced, so digits and the
/// currency symbol don't get visually reordered inside the RTL layout.
class AmountText extends StatelessWidget {
  const AmountText(this.value,
      {super.key, this.currency = AppCurrency.usd, this.style, this.color});

  final double value;
  final AppCurrency currency;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        currency.format(value),
        style: (style ?? const TextStyle()).copyWith(color: color),
      ),
    );
  }
}
