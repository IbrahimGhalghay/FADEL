import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/currency_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../auth/providers/session_providers.dart';
import '../../settings/providers/labels_providers.dart';
import '../data/supplier_transaction_model.dart';
import '../providers/supplier_providers.dart';

/// Record cargo received from a supplier (with a note describing it) or a
/// payment made to them, or edit an existing entry.
class AddEditSupplierTransactionScreen extends ConsumerStatefulWidget {
  const AddEditSupplierTransactionScreen({
    super.key,
    required this.supplierId,
    this.entry,
    this.initialType = SupplierTxType.cargo,
  });

  final String supplierId;
  final SupplierTransaction? entry;
  final SupplierTxType initialType;

  @override
  ConsumerState<AddEditSupplierTransactionScreen> createState() =>
      _AddEditSupplierTransactionScreenState();
}

class _AddEditSupplierTransactionScreenState
    extends ConsumerState<AddEditSupplierTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
      text: widget.entry == null
          ? ''
          : widget.entry!.amount.toStringAsFixed(
              widget.entry!.amount.truncateToDouble() == widget.entry!.amount
                  ? 0
                  : 2));
  late final _noteController = TextEditingController(text: widget.entry?.note);
  late SupplierTxType _type = widget.entry?.type ?? widget.initialType;
  late AppCurrency _currency = widget.entry?.currency ?? AppCurrency.usd;
  late DateTime _date = widget.entry?.date ?? DateTime.now();
  bool _payDirectly = false;

  bool get _isEditing => widget.entry != null;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(supplierRepositoryProvider);
    final amount = double.parse(_amountController.text.trim());
    final note = _noteController.text.trim();
    if (_isEditing) {
      repo.updateEntry(
        supplierId: widget.supplierId,
        old: widget.entry!,
        type: _type,
        amount: amount,
        currency: _currency,
        date: _date,
        note: note,
      );
    } else {
      final session = ref.read(sessionControllerProvider);
      repo.addEntry(
        supplierId: widget.supplierId,
        type: _type,
        amount: amount,
        currency: _currency,
        date: _date,
        note: note,
        createdBy: ref.read(authRepositoryProvider).currentUid ?? '',
        createdByName: session.userName,
        payDirectly: _payDirectly,
      );
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final labels = ref.watch(labelsProvider);
    final isCargo = _type == SupplierTxType.cargo;
    final title = _isEditing
        ? AppStrings.editTransaction
        : isCargo
            ? labels.recordCargo
            : labels.recordPayment;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<SupplierTxType>(
                segments: [
                  ButtonSegment(
                    value: SupplierTxType.cargo,
                    label: Text(labels.cargo),
                    icon: const Icon(Icons.arrow_upward,
                        color: AppTheme.debtColor),
                  ),
                  ButtonSegment(
                    value: SupplierTxType.payment,
                    label: Text(labels.payment),
                    icon: const Icon(Icons.arrow_downward,
                        color: AppTheme.paidColor),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: AppStrings.amount,
                  // Follows the currency toggle below ($ or ل.س).
                  prefixIcon: SizedBox(
                    width: 48,
                    child: Center(
                      child: Text(
                        _currency.symbol,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                // Numeric entry stays LTR inside the RTL layout.
                textDirection: TextDirection.ltr,
                validator: Validators.positiveAmount,
                autofocus: !_isEditing,
              ),
              const SizedBox(height: 16),
              // Currency of this entry — balances are tracked independently
              // per currency and never converted.
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: AppStrings.currency,
                  prefixIcon: Icon(Icons.currency_exchange),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: SegmentedButton<AppCurrency>(
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: AppCurrency.usd,
                      label: Text(AppStrings.currencyUsd),
                    ),
                    ButtonSegment(
                      value: AppCurrency.syp,
                      label: Text(AppStrings.currencySyp),
                    ),
                  ],
                  selected: {_currency},
                  onSelectionChanged: (selection) =>
                      setState(() => _currency = selection.first),
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: AppStrings.date,
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: InkWell(
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(Formatters.date(_date),
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.end),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  // On cargo the note describes the shipment itself.
                  labelText:
                      isCargo ? AppStrings.cargoNote : AppStrings.note,
                  prefixIcon: const Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
              ),
              // "Pay Directly": cargo-only, new entries only — records a
              // matching payment in the same atomic write.
              if (!_isEditing && isCargo) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _payDirectly,
                  onChanged: (value) =>
                      setState(() => _payDirectly = value ?? false),
                  title: const Text(AppStrings.payDirectly),
                  subtitle: const Text(AppStrings.payDirectlyCargoHint),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: const Text(AppStrings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
