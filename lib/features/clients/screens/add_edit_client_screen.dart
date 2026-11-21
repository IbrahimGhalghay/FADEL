import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../data/client_model.dart';
import '../providers/client_providers.dart';

/// Add a new client, or edit an existing one when [client] is provided.
class AddEditClientScreen extends ConsumerStatefulWidget {
  const AddEditClientScreen({super.key, this.client});

  final Client? client;

  @override
  ConsumerState<AddEditClientScreen> createState() =>
      _AddEditClientScreenState();
}

class _AddEditClientScreenState extends ConsumerState<AddEditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.client?.name);
  late final _phoneController =
      TextEditingController(text: widget.client?.phone);
  late final _notesController =
      TextEditingController(text: widget.client?.notes);
  String? _nameError;

  bool get _isEditing => widget.client != null;

  /// Another client (different id) already registered with this exact name?
  /// Checked against the live client list, so it also works offline.
  bool _isDuplicateName(String name) {
    final clients = ref.read(clientsStreamProvider).value ?? const [];
    return clients.any(
        (c) => c.name.trim() == name && c.id != widget.client?.id);
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
      setState(() => _nameError = AppStrings.duplicateClientName);
      return;
    }
    final repo = ref.read(clientRepositoryProvider);
    final phone = _phoneController.text.trim();
    final notes = _notesController.text.trim();
    if (_isEditing) {
      repo.updateClient(widget.client!,
          name: name, phone: phone, notes: notes);
    } else {
      repo.addClient(name: name, phone: phone, notes: notes);
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? AppStrings.editClient : AppStrings.addClient),
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
                  labelText: AppStrings.clientName,
                  prefixIcon: const Icon(Icons.person_outline),
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
