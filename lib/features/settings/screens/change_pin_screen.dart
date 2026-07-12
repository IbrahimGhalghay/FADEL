import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../auth/providers/session_providers.dart';
import '../../auth/widgets/pin_entry_view.dart';

enum _Stage { current, newPin, confirm }

/// Three-stage PIN change: verify current → enter new → confirm new.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  _Stage _stage = _Stage.current;
  String? _newPin;

  Future<String?> _onSubmit(String pin) async {
    switch (_stage) {
      case _Stage.current:
        final ok = await ref.read(pinRepositoryProvider).verifyPin(pin);
        if (!ok) return AppStrings.wrongPin;
        setState(() => _stage = _Stage.newPin);
        return null;
      case _Stage.newPin:
        setState(() {
          _newPin = pin;
          _stage = _Stage.confirm;
        });
        return null;
      case _Stage.confirm:
        if (pin != _newPin) {
          setState(() {
            _newPin = null;
            _stage = _Stage.newPin;
          });
          return AppStrings.pinMismatch;
        }
        await ref.read(pinRepositoryProvider).setPin(pin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.pinChanged)),
          );
          context.pop();
        }
        return null;
    }
  }

  String get _title => switch (_stage) {
        _Stage.current => AppStrings.currentPin,
        _Stage.newPin => AppStrings.newPin,
        _Stage.confirm => AppStrings.confirmPin,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.changePin)),
      body: SafeArea(
        child: PinEntryView(
          key: ValueKey(_stage),
          icon: Icons.pin_outlined,
          title: _title,
          onSubmit: _onSubmit,
        ),
      ),
    );
  }
}
