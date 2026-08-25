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

  /// Firestore key -> (field caption, hint/default, live value).
  late final Map<String, (String, String, TextEditingController)> _fields;

  @override
  void initState() {
    super.initState();
    final labels = ref.read(labelsProvider);
    _fields = {
      'debt': (AppStrings.labelDebt, AppStrings.debt, labels.debt),
      'payment': (AppStrings.labelPayment, AppStrings.payment, labels.payment),
      'recordDebt':
          (AppStrings.labelRecordDebt, AppStrings.recordDebt, labels.recordDebt),
      'recordPayment': (
        AppStrings.labelRecordPayment,
        AppStrings.recordPayment,
        labels.recordPayment
      ),
      'suppliers':
          (AppStrings.labelSuppliers, AppStrings.suppliers, labels.suppliers),
      'supplier':
          (AppStrings.labelSupplier, AppStrings.supplier, labels.supplier),
      'cargo': (AppStrings.labelCargo, AppStrings.cargo, labels.cargo),
      'recordCargo':
          (AppStrings.labelRecordCargo, AppStrings.recordCargo, labels.recordCargo),
    }.map((key, value) => MapEntry(
          key,
          (value.$1, value.$2, TextEditingController(text: value.$3)),
        ));
  }

  @override
  void dispose() {
    for (final (_, _, controller) in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final businessId = ref.read(sessionControllerProvider).businessId;
    if (businessId == null) return;
    // Empty fields are stored as-is; AppLabels.fromMap falls back to the
    // built-in default for any blank value.
    ref.read(authRepositoryProvider).updateBusinessLabels(
          businessId,
          _fields.map((key, value) => MapEntry(key, value.$3.text.trim())),
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
              for (final (caption, hint, controller) in _fields.values) ...[
                TextFormField(
                  controller: controller,
                  decoration:
                      InputDecoration(labelText: caption, hintText: hint),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
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
