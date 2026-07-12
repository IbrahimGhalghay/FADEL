import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../auth/providers/session_providers.dart';
import '../data/transaction_model.dart';
import '../providers/transaction_providers.dart';

/// Record a new debt/payment, or edit an existing transaction.
class AddEditTransactionScreen extends ConsumerStatefulWidget {
  const AddEditTransactionScreen({
    super.key,
    required this.clientId,
    this.transaction,
    this.initialType = TxType.debt,
  });

  final String clientId;
  final ClientTransaction? transaction;
  final TxType initialType;

  @override
  ConsumerState<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState
    extends ConsumerState<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
      text: widget.transaction == null
          ? ''
          : widget.transaction!.amount.toStringAsFixed(
              widget.transaction!.amount.truncateToDouble() ==
                      widget.transaction!.amount
                  ? 0
                  : 2));
  late final _noteController =
      TextEditingController(text: widget.transaction?.note);
  late TxType _type = widget.transaction?.type ?? widget.initialType;
  late DateTime _date = widget.transaction?.date ?? DateTime.now();

  bool get _isEditing => widget.transaction != null;

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
    final repo = ref.read(transactionRepositoryProvider);
    final amount = double.parse(_amountController.text.trim());
    final note = _noteController.text.trim();
    if (_isEditing) {
      repo.updateTransaction(
        clientId: widget.clientId,
        old: widget.transaction!,
        type: _type,
        amount: amount,
        date: _date,
        note: note,
      );
    } else {
      repo.addTransaction(
        clientId: widget.clientId,
        type: _type,
        amount: amount,
        date: _date,
        note: note,
        createdBy: ref.read(authRepositoryProvider).currentUid ?? '',
      );
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing
        ? AppStrings.editTransaction
        : _type == TxType.debt
            ? AppStrings.recordDebt
            : AppStrings.recordPayment;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TxType>(
                segments: const [
                  ButtonSegment(
                    value: TxType.debt,
                    label: Text(AppStrings.debt),
                    icon: Icon(Icons.arrow_upward,
                        color: AppTheme.debtColor),
                  ),
                  ButtonSegment(
                    value: TxType.payment,
                    label: Text(AppStrings.payment),
                    icon: Icon(Icons.arrow_downward,
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
                decoration: const InputDecoration(
                  labelText: AppStrings.amount,
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                // Numeric entry stays LTR inside the RTL layout.
                textDirection: TextDirection.ltr,
                validator: Validators.positiveAmount,
                autofocus: !_isEditing,
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
                decoration: const InputDecoration(
                  labelText: AppStrings.note,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 2,
              ),
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
