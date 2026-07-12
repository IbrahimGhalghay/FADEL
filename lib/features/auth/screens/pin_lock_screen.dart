import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../providers/session_providers.dart';
import '../widgets/pin_entry_view.dart';

/// Shown on launch and whenever the auto-lock timeout expires.
class PinLockScreen extends ConsumerWidget {
  const PinLockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: PinEntryView(
          title: AppStrings.enterPin,
          onSubmit: (pin) async {
            final ok =
                await ref.read(sessionControllerProvider.notifier).unlock(pin);
            return ok ? null : AppStrings.wrongPin;
          },
        ),
      ),
    );
  }
}
