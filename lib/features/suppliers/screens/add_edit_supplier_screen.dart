import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../settings/providers/labels_providers.dart';
import '../data/supplier_model.dart';
import '../providers/supplier_providers.dart';

/// Add a new supplier, or edit an existing one when [supplier] is provided.
class AddEditSupplierScreen extends ConsumerStatefulWidget {
  const AddEditSupplierScreen({super.key, this.supplier});

  final Supplier? supplier;

  @override
  ConsumerState<AddEditSupplierScreen> createState() =>
      _AddEditSupplierScreenState();
}

class _AddEditSupplierScreenState extends ConsumerState<AddEditSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.supplier?.name);
  late final _phoneController =
      TextEditingController(text: widget.supplier?.phone);
  late final _notesController =
      TextEditingController(text: widget.supplier?.notes);
  String? _nameError;

  bool get _isEditing => widget.supplier != null;

  /// Another supplier (different id) already registered under this exact
  /// name? Checked against the live list, so it also works offline.
  bool _isDuplicateName(String name) {
    final suppliers = ref.read(suppliersStreamProvider).value ?? const [];
    return suppliers
        .any((s) => s.name.trim() == name && s.id != widget.supplier?.id);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    if (_isDuplicateName(name)) {
      setState(() => _nameError = AppStrings.duplicateSupplierName);
      return;
    }
    final repo = ref.read(supplierRepositoryProvider);
    final phone = _phoneController.text.trim();
    final notes = _notesController.text.trim();
    if (_isEditing) {
      repo.updateSupplier(widget.supplier!,
          name: name, phone: phone, notes: notes);
    } else {
      repo.addSupplier(name: name, phone: phone, notes: notes);
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final noun = ref.watch(labelsProvider).supplier;
    return Scaffold(
      appBar: AppBar(
        title:
            Text(_isEditing ? AppStrings.editOf(noun) : AppStrings.addOf(noun)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: AppStrings.nameField,
                  prefixIcon: const Icon(Icons.storefront_outlined),
                  errorText: _nameError,
                  errorMaxLines: 2,
                ),
                textInputAction: TextInputAction.next,
                validator: Validators.required,
                autofocus: !_isEditing,
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: AppStrings.phone,
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                // Phone numbers read LTR even in Arabic UI.
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: AppStrings.notes,
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
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
