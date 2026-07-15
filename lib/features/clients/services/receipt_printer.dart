import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/currency_config.dart';
import '../../../core/utils/formatters.dart';
import '../../settings/providers/labels_providers.dart';
import '../../transactions/data/transaction_model.dart';
import '../data/client_model.dart';

/// Builds a client account statement PDF sized for small thermal receipt
/// printers (58mm roll) and opens the Android share sheet — send it to the
/// thermal printer's app (vendor app / RawBT), a PDF viewer to print from,
/// or straight to the client on WhatsApp.
class ReceiptPrinter {
  ReceiptPrinter._();

  /// 58mm thermal roll (printable width ≈48mm). Change here if the business
  /// ever switches to 80mm paper (use PdfPageFormat.roll80).
  static const PdfPageFormat _format = PdfPageFormat.roll57;

  static Future<void> printClientStatement({
    required Client client,
    required List<ClientTransaction> transactions,
    required AppLabels labels,
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
                child: pw.Text(AppStrings.receiptTitle,
                    style: const pw.TextStyle(fontSize: 9)),
              ),
              _divider(),
              _row('${AppStrings.clientName}:', client.name, bold: true),
              if (client.phone != null)
                _row('${AppStrings.phone}:', client.phone!, ltrValue: true),
              _row('${AppStrings.receiptPrintedOn}:',
                  Formatters.date(DateTime.now()), ltrValue: true),
              _divider(),
              // --- Transactions, oldest first on paper ---
              for (final tx in transactions.reversed) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${_typeLabel(tx, labels)}  ${Formatters.date(tx.date)}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    _amount(tx.currency, tx.amount,
                        pw.TextStyle(font: bold, fontSize: 8)),
                  ],
                ),
                if (tx.note != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 8),
                    child: pw.Text(tx.note!,
                        style: const pw.TextStyle(fontSize: 7)),
                  ),
                pw.SizedBox(height: 2),
              ],
              if (transactions.isEmpty)
                pw.Center(
                  child: pw.Text(AppStrings.noTransactions,
                      style: const pw.TextStyle(fontSize: 8)),
                ),
              _divider(),
              // --- Balance per currency (only currencies with activity) ---
              for (final currency in AppCurrency.values)
                if (client.balance(currency) != 0 ||
                    transactions.any((t) => t.currency == currency))
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${AppStrings.balance} (${currency.symbol}):',
                          style: const pw.TextStyle(fontSize: 8)),
                      _amount(currency, client.balance(currency),
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
      subject: '${AppStrings.receiptTitle} - ${client.name}',
    ));
  }

  static String _typeLabel(ClientTransaction tx, AppLabels labels) =>
      tx.type == TxType.debt ? labels.debt : labels.payment;

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
