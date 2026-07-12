import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// Renders a currency amount with LTR direction forced, so digits and the
/// currency symbol don't get visually reordered inside the RTL layout.
class AmountText extends StatelessWidget {
  const AmountText(this.value, {super.key, this.style, this.color});

  final double value;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        Formatters.currency(value),
        style: (style ?? const TextStyle()).copyWith(color: color),
      ),
    );
  }
}
