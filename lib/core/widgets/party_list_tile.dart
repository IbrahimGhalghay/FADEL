import 'package:flutter/material.dart';

import '../models/ledger_party.dart';
import '../theme/app_theme.dart';
import 'amount_text.dart';

/// List row for a client or a supplier: initial, name, phone, and one
/// amount line per currency with a non-zero balance.
class PartyListTile extends StatelessWidget {
  const PartyListTile({
    super.key,
    required this.party,
    required this.onTap,
    required this.onLongPress,
  });

  final LedgerParty party;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: CircleAvatar(
        child: Text(party.name.isEmpty ? '؟' : party.name.characters.first),
      ),
      title: Text(party.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: party.phone == null
          ? null
          : Directionality(
              textDirection: TextDirection.ltr,
              child: Text(party.phone!, textAlign: TextAlign.end),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trailing column reads top-down, so keep the natural currency
          // order here rather than the RTL row order.
          for (final (currency, value) in party.visibleBalances.reversed)
            AmountText(
              value,
              currency: currency,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              color: value > 0 ? AppTheme.debtColor : AppTheme.paidColor,
            ),
        ],
      ),
    );
  }
}
