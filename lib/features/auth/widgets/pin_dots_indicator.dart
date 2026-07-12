import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// Shows one filled dot per entered PIN digit (up to the max PIN length).
class PinDotsIndicator extends StatelessWidget {
  const PinDotsIndicator({super.key, required this.enteredLength});

  final int enteredLength;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < AppConstants.pinMaxLength; i++)
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < enteredLength ? color : Colors.transparent,
              border: Border.all(color: color, width: 2),
            ),
          ),
      ],
    );
  }
}
