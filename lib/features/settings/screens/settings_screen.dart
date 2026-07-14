import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/session_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessId =
        ref.watch(sessionControllerProvider.select((s) => s.businessId));
    final timeout = ref.watch(lockTimeoutProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: ListView(
        children: [
          // --- Business ID (share with a new employee's device) ---
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text(AppStrings.businessId),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    businessId ?? '—',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const Text(AppStrings.businessIdCopyHint,
                    style: TextStyle(fontSize: 12)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: businessId == null
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: businessId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(AppStrings.copied)),
                        );
                      }
                    },
            ),
          ),
          const Divider(),
          // --- Change PIN ---
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: const Text(AppStrings.changePin),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push('/settings/pin'),
          ),
          const Divider(),
          // --- Customize captions ---
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text(AppStrings.editLabels),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push('/settings/labels'),
          ),
          const Divider(),
          // --- Auto-lock timeout ---
          ListTile(
            leading: const Icon(Icons.lock_clock_outlined),
            title: const Text(AppStrings.lockTimeout),
            trailing: DropdownButton<int>(
              value: timeout.inSeconds,
              onChanged: (seconds) {
                if (seconds != null) {
                  ref
                      .read(lockTimeoutProvider.notifier)
                      .set(Duration(seconds: seconds));
                }
              },
              items: [
                for (final option in AppConstants.lockTimeoutOptions)
                  DropdownMenuItem(
                    value: option.inSeconds,
                    child: Text(option == Duration.zero
                        ? AppStrings.lockImmediately
                        : AppStrings.minutesLabel(option.inMinutes)),
                  ),
              ],
            ),
          ),
          const Divider(),
          // --- App version ---
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text(AppStrings.appVersion),
              subtitle: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  snapshot.hasData
                      ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                      : '...',
                  textAlign: TextAlign.end,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
