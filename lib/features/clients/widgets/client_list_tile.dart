import 'package:flutter/material.dart';

import '../../../core/constants/currency_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/amount_text.dart';
import '../data/client_model.dart';

class ClientListTile extends StatelessWidget {
  const ClientListTile({
    super.key,
    required this.client,
    required this.onTap,
    required this.onLongPress,
  });

  final Client client;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    // One line per currency with a non-zero balance; a settled client
    // shows a single green $0.00.
    final visible = AppCurrency.values
        .where((currency) => client.balance(currency) != 0)
        .toList();
    if (visible.isEmpty) visible.add(AppCurrency.usd);

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: CircleAvatar(
        child: Text(client.name.isEmpty ? '؟' : client.name.characters.first),
      ),
      title: Text(client.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: client.phone == null
          ? null
          : Directionality(
              textDirection: TextDirection.ltr,
              child: Text(client.phone!, textAlign: TextAlign.end),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final currency in visible)
            AmountText(
              client.balance(currency),
              currency: currency,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
              color: client.balance(currency) > 0
                  ? AppTheme.debtColor
                  : AppTheme.paidColor,
            ),
        ],
      ),
    );
  }
}
