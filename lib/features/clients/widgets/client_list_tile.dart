import 'package:flutter/material.dart';

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
    final owes = client.balance > 0;
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
      trailing: AmountText(
        client.balance,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        color: owes ? AppTheme.debtColor : AppTheme.paidColor,
      ),
    );
  }
}
