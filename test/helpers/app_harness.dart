import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/app.dart';
import 'package:myfit_tracker/core/database/app_database.dart';
import 'package:myfit_tracker/core/providers/core_providers.dart';
import 'package:myfit_tracker/features/profile/user_profile.dart';
import 'package:myfit_tracker/features/settings/app_settings.dart';

import 'test_db.dart';

/// Monday 2 November 2026.
final today = DateTime(2026, 11, 2);

Future<AppDatabase> pumpApp(
  WidgetTester tester, {
  bool onboarded = true,
  UserProfile? profile,
  Future<void> Function(AppDatabase db)? seed,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3; // 360 × 780 logical pixels
  addTearDown(tester.view.reset);

  late AppDatabase db;
  late AppSettings settings;
  late UserProfile loadedProfile;
  await tester.runAsync(() async {
    // A separate file per test: repeated opens of ':memory:' share one instance.
    db = await openTestDatabase(path: tempDatabasePath('widget'));
    if (onboarded) {
      await SettingsRepository(db).save(const AppSettings(onboardingCompleted: true));
      await ProfileRepository(db).save(profile ?? const UserProfile(name: 'Saransh Jais'));
    }
    if (seed != null) await seed(db);
    settings = await SettingsRepository(db).load();
    loadedProfile = await ProfileRepository(db).load();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
        initialProfileProvider.overrideWithValue(loadedProfile),
        todayProvider.overrideWith(() => FixedTodayNotifier(today)),
        ...overrides,
      ],
      child: const MyFitApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

/// Pumps a few frames without waiting for periodic timers to stop.
Future<void> settleFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
