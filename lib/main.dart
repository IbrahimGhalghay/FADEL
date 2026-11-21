import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'core/services/activity_log.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Full offline support: cache everything, sync when connectivity returns.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  await initializeDateFormatting('ar');
  // Stamped on every activity-log record.
  final info = await PackageInfo.fromPlatform();
  runApp(ProviderScope(
    overrides: [
      appVersionProvider
          .overrideWithValue('${info.version}+${info.buildNumber}'),
    ],
    child: const FadelApp(),
  ));
}
