import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import 'pin_dots_indicator.dart';
import 'pin_keypad.dart';

/// Reusable PIN entry: title, dots, keypad, error text + shake animation.
///
/// [onSubmit] receives the entered PIN and returns an error message to show
/// (with a shake), or null when accepted. The field clears after every submit,
/// so multi-stage flows (new PIN → confirm) can just swap [title] between
/// stages from the parent.
class PinEntryView extends StatefulWidget {
  const PinEntryView({
    super.key,
    required this.title,
    required this.onSubmit,
    this.icon = Icons.lock_outline,
  });

  final String title;
  final IconData icon;
  final Future<String?> Function(String pin) onSubmit;

  @override
  State<PinEntryView> createState() => _PinEntryViewState();
}

class _PinEntryViewState extends State<PinEntryView>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _busy = false;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_busy || _pin.length >= AppConstants.pinMaxLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == AppConstants.pinMaxLength) _submit();
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_pin.length < AppConstants.pinMinLength) return;
    setState(() => _busy = true);
    final error = await widget.onSubmit(_pin);
    if (!mounted) return;
    setState(() {
      _pin = '';
      _error = error;
      _busy = false;
    });
    if (error != null) _shakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(widget.icon, size: 56,
            color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(widget.title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final progress = _shakeController.value;
            // Damped horizontal shake.
            final offset = (1 - progress) *
                12 *
                (progress * 40).remainder(2) *
                ((progress * 40).truncate().isEven ? 1 : -1);
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: PinDotsIndicator(enteredLength: _pin.length),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 24,
          child: _error == null
              ? null
              : Text(
                  _error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600),
                ),
        ),
        const SizedBox(height: 12),
        PinKeypad(
          onDigit: _addDigit,
          onBackspace: _backspace,
          onSubmit: _submit,
          submitEnabled:
              !_busy && _pin.length >= AppConstants.pinMinLength,
        ),
      ],
    );
  }
}
