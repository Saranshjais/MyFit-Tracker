import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/seed_data.dart';
import 'core/providers/core_providers.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/user_profile.dart';
import 'features/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final AppDatabase db;
  try {
    db = await AppDatabase.open(
      factory: databaseFactory,
      path: p.join(await getDatabasesPath(), AppDatabase.fileName),
      seed: await SeedData.fromBundle(rootBundle),
    );
  } catch (e, st) {
    debugPrint('Database failed to open: $e\n$st');
    runApp(StartupErrorApp(error: e));
    return;
  }

  final notifications = LocalNotificationService();
  await notifications.init();

  final settings = await SettingsRepository(db).load();
  final profile = await ProfileRepository(db).load();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notifications),
        initialSettingsProvider.overrideWithValue(settings),
        initialProfileProvider.overrideWithValue(profile),
      ],
      child: const MyFitApp(),
    ),
  );
}

/// Shown if the local database cannot be opened, instead of a blank screen.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(AppPalette.dark, Brightness.dark),
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storage_rounded, size: 40),
              const SizedBox(height: 16),
              const Text(
                'MyFit Tracker could not open its data',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your data has not been deleted. Try closing and reopening the app. '
                'If this keeps happening, free up storage space on the phone.',
              ),
              const SizedBox(height: 16),
              Text('$error', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    ),
  );
}
