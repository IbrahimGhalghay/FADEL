import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/routing/app_router.dart';
import 'core/services/activity_log.dart';
import 'core/services/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/session_providers.dart';

class FadelApp extends ConsumerStatefulWidget {
  const FadelApp({super.key});

  @override
  ConsumerState<FadelApp> createState() => _FadelAppState();
}

class _FadelAppState extends ConsumerState<FadelApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Auto-lock: timestamp on background, re-lock on resume if timed out.
    _lifecycleListener = AppLifecycleListener(
      onHide: () =>
          ref.read(sessionControllerProvider.notifier).onAppBackgrounded(),
      onResume: () {
        ref.read(sessionControllerProvider.notifier).onAppResumed();
        // Android may have left the Firestore connection stale while in the
        // background; catch up so other devices' entries show at once.
        // (Skipped before joining a business: onboarding does server reads.)
        if (ref.read(sessionControllerProvider).businessId != null) {
          ref.read(syncServiceProvider).resyncInBackground();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appTitle,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: scaffoldMessengerKey,
      // Arabic-only, RTL-first.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}
