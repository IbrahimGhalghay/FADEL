import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../constants/app_strings.dart';
import '../constants/currency_config.dart';
import '../models/ledger_party.dart';
import '../utils/formatters.dart';

/// One printed history line — a debt/payment for a client, or a
/// cargo/payment for a supplier.
typedef StatementLine = ({
  String label,
  DateTime date,
  double amount,
  AppCurrency currency,
  String? note,
});

/// Builds an account statement PDF sized for small thermal receipt printers
/// (58mm roll) and opens the Android share sheet — send it to the thermal
/// printer's app (vendor app / RawBT), a PDF viewer to print from, or
/// straight to the client on WhatsApp.
class ReceiptPrinter {
  ReceiptPrinter._();

  /// 58mm thermal roll (printable width ≈48mm). Change here if the business
  /// ever switches to 80mm paper (use PdfPageFormat.roll80).
  static const PdfPageFormat _format = PdfPageFormat.roll57;

  /// [lines] arrive newest-first (as displayed) and are printed oldest-first.
  /// [activeCurrencies] adds currencies to the balance footer even when they
  /// have settled to zero, so a fully paid-off currency still shows.
  static Future<void> printStatement({
    required String title,
    required String nameLabel,
    required LedgerParty party,
    required List<StatementLine> lines,
    required Set<AppCurrency> activeCurrencies,
  }) async {
    final regular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: _format,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        margin: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(AppStrings.appTitle,
                    style: pw.TextStyle(font: bold, fontSize: 12)),
              ),
              pw.Center(
                child: pw.Text(title, style: const pw.TextStyle(fontSize: 9)),
              ),
              _divider(),
              _row('$nameLabel:', party.name, bold: true),
              if (party.phone != null)
                _row('${AppStrings.phone}:', party.phone!, ltrValue: true),
              _row('${AppStrings.receiptPrintedOn}:',
                  Formatters.date(DateTime.now()), ltrValue: true),
              _divider(),
              // --- History, oldest first on paper ---
              for (final line in lines.reversed) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${line.label}  ${Formatters.date(line.date)}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    _amount(line.currency, line.amount,
                        pw.TextStyle(font: bold, fontSize: 8)),
                  ],
                ),
                if (line.note != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 8),
                    child: pw.Text(line.note!,
                        style: const pw.TextStyle(fontSize: 7)),
                  ),
                pw.SizedBox(height: 2),
              ],
              if (lines.isEmpty)
                pw.Center(
                  child: pw.Text(AppStrings.noTransactions,
                      style: const pw.TextStyle(fontSize: 8)),
                ),
              _divider(),
              // --- Balance per currency (only currencies with activity) ---
              for (final currency in AppCurrency.values)
                if (party.balance(currency) != 0 ||
                    activeCurrencies.contains(currency))
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${AppStrings.balance} (${currency.symbol}):',
                          style: const pw.TextStyle(fontSize: 8)),
                      _amount(currency, party.balance(currency),
                          pw.TextStyle(font: bold, fontSize: 8)),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    // ASCII-safe file name; some share targets choke on Arabic names.
    final file = File(
        '${dir.path}/statement-${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: '$title - ${party.name}',
    ));
  }

  /// USD renders as an LTR run ($1,250.00). SYP stays in the RTL context so
  /// the pdf bidi engine keeps the "ل.س" suffix letters in correct order.
  static pw.Widget _amount(
          AppCurrency currency, double value, pw.TextStyle style) =>
      currency == AppCurrency.usd
          ? pw.Directionality(
              textDirection: pw.TextDirection.ltr,
              child: pw.Text(currency.format(value), style: style),
            )
          : pw.Text(currency.format(value), style: style);

  static pw.Widget _divider() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Container(height: 0.5, color: PdfColors.black),
      );

  static pw.Widget _row(String label, String value,
          {bool bold = false, bool ltrValue = false}) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Flexible(
            child: ltrValue
                ? pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Text(value,
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: bold
                                ? pw.FontWeight.bold
                                : pw.FontWeight.normal)),
                  )
                : pw.Text(value,
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: bold
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal)),
          ),
        ],
      );
}
