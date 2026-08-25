import '../constants/currency_config.dart';

/// A named party the business keeps a running balance with — a client (who
/// owes us) or a supplier (whom we owe). A positive balance always means
/// money is still outstanding in that party's direction.
abstract interface class LedgerParty {
  String get id;
  String get name;
  String? get phone;
  String? get notes;

  double balance(AppCurrency currency);
}

extension LedgerPartyX on LedgerParty {
  /// Currencies carrying a non-zero balance, ordered for RTL display
  /// (first entry sits on the right). A fully settled party still shows a
  /// single USD zero rather than nothing at all.
  List<(AppCurrency, double)> get visibleBalances {
    final visible = [
      for (final currency in AppCurrency.values.reversed)
        if (balance(currency) != 0) (currency, balance(currency)),
    ];
    return visible.isEmpty ? [(AppCurrency.usd, 0.0)] : visible;
  }
}
