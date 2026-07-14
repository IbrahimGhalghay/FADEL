import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../auth/providers/session_providers.dart';
import '../providers/labels_providers.dart';

/// Edits the business-wide button/transaction captions
/// (e.g. rename "تسجيل دين" to "عملية بيع"). Syncs to all employees.
class EditLabelsScreen extends ConsumerStatefulWidget {
  const EditLabelsScreen({super.key});

  @override
  ConsumerState<EditLabelsScreen> createState() => _EditLabelsScreenState();
}

class _EditLabelsScreenState extends ConsumerState<EditLabelsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _recordDebt;
  late final TextEditingController _recordPayment;
  late final TextEditingController _debt;
  late final TextEditingController _payment;

  @override
  void initState() {
    super.initState();
    final labels = ref.read(labelsProvider);
    _recordDebt = TextEditingController(text: labels.recordDebt);
    _recordPayment = TextEditingController(text: labels.recordPayment);
    _debt = TextEditingController(text: labels.debt);
    _payment = TextEditingController(text: labels.payment);
  }

  @override
  void dispose() {
    _recordDebt.dispose();
    _recordPayment.dispose();
    _debt.dispose();
    _payment.dispose();
    super.dispose();
  }

  void _save() {
    final businessId = ref.read(sessionControllerProvider).businessId;
    if (businessId == null) return;
    // Empty fields are stored as-is; AppLabels.fromMap falls back to the
    // built-in default for any blank value.
    ref.read(authRepositoryProvider).updateBusinessLabels(
          businessId,
          {
            'recordDebt': _recordDebt.text.trim(),
            'recordPayment': _recordPayment.text.trim(),
            'debt': _debt.text.trim(),
            'payment': _payment.text.trim(),
          },
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.labelsSaved)),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.editLabels)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.editLabelsSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              TextFormField(
                controller: _debt,
                decoration: const InputDecoration(
                    labelText: AppStrings.labelDebt,
                    hintText: AppStrings.debt),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _payment,
                decoration: const InputDecoration(
                    labelText: AppStrings.labelPayment,
                    hintText: AppStrings.payment),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _recordDebt,
                decoration: const InputDecoration(
                    labelText: AppStrings.labelRecordDebt,
                    hintText: AppStrings.recordDebt),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _recordPayment,
                decoration: const InputDecoration(
                    labelText: AppStrings.labelRecordPayment,
                    hintText: AppStrings.recordPayment),
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
