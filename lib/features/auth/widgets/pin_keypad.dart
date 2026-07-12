import 'package:flutter/material.dart';

/// Numeric 3x4 keypad: digits 1-9, backspace, 0, submit.
/// Forced LTR so the digit order never mirrors under the app's RTL layout.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    required this.submitEnabled,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final bool submitEnabled;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Row(
                children: [for (final d in row) _digitKey(context, d)],
              ),
            Row(
              children: [
                _key(
                  context,
                  child: const Icon(Icons.backspace_outlined),
                  onTap: onBackspace,
                ),
                _digitKey(context, '0'),
                _key(
                  context,
                  child: Icon(
                    Icons.check_circle,
                    size: 36,
                    color: submitEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).disabledColor,
                  ),
                  onTap: submitEnabled ? onSubmit : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _digitKey(BuildContext context, String digit) => _key(
        context,
        child: Text(digit, style: const TextStyle(fontSize: 28)),
        onTap: () => onDigit(digit),
      );

  Widget _key(BuildContext context,
      {required Widget child, VoidCallback? onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: SizedBox(height: 68, child: Center(child: child)),
        ),
      ),
    );
  }
}
