import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/session_providers.dart';
import '../../features/auth/screens/onboarding/business_setup_screen.dart';
import '../../features/auth/screens/onboarding/name_setup_screen.dart';
import '../../features/auth/screens/onboarding/pin_setup_screen.dart';
import '../../features/auth/screens/pin_lock_screen.dart';
import '../../features/clients/data/client_model.dart';
import '../../features/clients/screens/add_edit_client_screen.dart';
import '../../features/clients/screens/client_detail_screen.dart';
import '../../features/clients/screens/dashboard_screen.dart';
import '../../features/settings/screens/change_pin_screen.dart';
import '../../features/settings/screens/edit_labels_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/transactions/data/transaction_model.dart';
import '../../features/transactions/screens/add_edit_transaction_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Bump a Listenable whenever the session changes so redirects re-evaluate.
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final location = state.matchedLocation;
      switch (session.status) {
        case SessionStatus.loading:
          return location == '/splash' ? null : '/splash';
        case SessionStatus.needsBusinessSetup:
          return location == '/setup/business' ? null : '/setup/business';
        case SessionStatus.needsName:
          return location == '/setup/name' ? null : '/setup/name';
        case SessionStatus.needsPinSetup:
          return location == '/setup/pin' ? null : '/setup/pin';
        case SessionStatus.locked:
          return location == '/lock' ? null : '/lock';
        case SessionStatus.unlocked:
          final isGate = location == '/splash' ||
              location == '/lock' ||
              location.startsWith('/setup');
          return isGate ? '/' : null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/setup/business',
        builder: (context, state) => const BusinessSetupScreen(),
      ),
      GoRoute(
        path: '/setup/name',
        builder: (context, state) => const NameSetupScreen(),
      ),
      GoRoute(
        path: '/setup/pin',
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/lock',
        builder: (context, state) => const PinLockScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/clients/new',
        builder: (context, state) => const AddEditClientScreen(),
      ),
      GoRoute(
        path: '/clients/:id',
        builder: (context, state) =>
            ClientDetailScreen(clientId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/clients/:id/edit',
        builder: (context, state) =>
            AddEditClientScreen(client: state.extra as Client?),
      ),
      GoRoute(
        path: '/clients/:id/tx/new',
        builder: (context, state) => AddEditTransactionScreen(
          clientId: state.pathParameters['id']!,
          initialType: state.uri.queryParameters['type'] == 'payment'
              ? TxType.payment
              : TxType.debt,
        ),
      ),
      GoRoute(
        path: '/clients/:id/tx/:txId/edit',
        builder: (context, state) => AddEditTransactionScreen(
          clientId: state.pathParameters['id']!,
          transaction: state.extra as ClientTransaction?,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/pin',
        builder: (context, state) => const ChangePinScreen(),
      ),
      GoRoute(
        path: '/settings/labels',
        builder: (context, state) => const EditLabelsScreen(),
      ),
    ],
  );
});
