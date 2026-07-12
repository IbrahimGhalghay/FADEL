import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../providers/session_providers.dart';
import '../../widgets/pin_entry_view.dart';

/// Two-stage PIN creation: enter new PIN, then confirm it.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String? _firstEntry;

  Future<String?> _onSubmit(String pin) async {
    if (_firstEntry == null) {
      setState(() => _firstEntry = pin);
      return null;
    }
    if (pin != _firstEntry) {
      setState(() => _firstEntry = null);
      return AppStrings.pinMismatch;
    }
    await ref.read(sessionControllerProvider.notifier).setPin(pin);
    // Router redirects to the dashboard once the session becomes unlocked.
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PinEntryView(
          key: ValueKey(_firstEntry == null),
          icon: Icons.pin_outlined,
          title: _firstEntry == null
              ? AppStrings.createPin
              : AppStrings.confirmPin,
          onSubmit: _onSubmit,
        ),
      ),
    );
  }
}
