import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/app.dart';
import 'package:myfit_tracker/core/database/app_database.dart';
import 'package:myfit_tracker/core/providers/core_providers.dart';
import 'package:myfit_tracker/core/utils/dates.dart';
import 'package:myfit_tracker/features/nutrition/food_log_repository.dart';
import 'package:myfit_tracker/features/nutrition/food_repository.dart';
import 'package:myfit_tracker/features/nutrition/nutrition_models.dart';
import 'package:myfit_tracker/features/profile/user_profile.dart';
import 'package:myfit_tracker/features/progress/body_repository.dart';
import 'package:myfit_tracker/features/settings/app_settings.dart';
import 'package:myfit_tracker/features/workout/session_repository.dart';

import '../helpers/test_db.dart';

/// Monday 2 November 2026.
final today = DateTime(2026, 11, 2);

Future<AppDatabase> pumpApp(
  WidgetTester tester, {
  bool onboarded = true,
  UserProfile? profile,
  Future<void> Function(AppDatabase db)? seed,
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

void main() {
  testWidgets('onboarding saves the profile and opens the dashboard', (tester) async {
    final db = await pumpApp(tester, onboarded: false);
    expect(find.text('Welcome to MyFit Tracker'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Saransh');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('About you'), findsOneWidget);
    await tester.tap(find.text('Male'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '22');
    await tester.enterText(find.widgetWithText(TextFormField, 'Height'), '183');
    await tester.enterText(find.widgetWithText(TextFormField, 'Current weight'), '64');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Your training'), findsOneWidget);
    await tester.tap(find.text('Gain muscle (bulk)'));
    await tester.ensureVisible(find.text('Moderately active'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moderately active'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Daily targets'), findsOneWidget);
    expect(find.text('How this estimate works'), findsOneWidget);
    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Saransh'), findsWidgets);
    // Four gym days (the default) gives the 4-day sample plan: Monday is Upper Body A.
    expect(find.text('Upper Body A'), findsOneWidget);

    await tester.runAsync(() async {
      final profile = await ProfileRepository(db).load();
      expect(profile.name, 'Saransh');
      expect(profile.calorieTarget, isNotNull);
      expect((await BodyRepository(db).latestWeight())!.weightKg, 64);
    });
  });

  testWidgets('bottom navigation reaches all five sections', (tester) async {
    await pumpApp(tester);
    expect(find.textContaining('Saransh'), findsWidgets);

    await tester.tap(find.text('Workout'));
    await tester.pumpAndSettle();
    expect(find.text('Workout Plan'), findsOneWidget);
    expect(find.text('Week Plan'), findsOneWidget);

    await tester.tap(find.text('Diet'));
    await tester.pumpAndSettle();
    expect(find.text('Diet / Nutrition'), findsOneWidget);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Settings & More'), findsOneWidget);
  });

  testWidgets('dashboard nutrition comes from saved food logs', (tester) async {
    await pumpApp(
      tester,
      profile: const UserProfile(
        name: 'Saransh',
        calorieTarget: 2000,
        proteinTarget: 120,
        carbsTarget: 250,
        fatTarget: 60,
      ),
      seed: (db) async {
        final roti = (await FoodRepository(db).search(query: 'Roti (whole wheat')).first;
        await FoodLogRepository(db).logFood(
          date: dateKey(today),
          category: 'Lunch',
          portion: FoodPortion(food: roti, serving: roti.servings[1], count: 2),
        );
      },
    );
    expect(find.text('204'), findsOneWidget);
    expect(find.text('/ 2,000 kcal'), findsOneWidget);
    expect(find.text('1,796 kcal remaining'), findsOneWidget);
  });

  testWidgets('starting a workout and logging a set', (tester) async {
    final db = await pumpApp(tester);
    expect(find.text('Chest & Triceps'), findsOneWidget);

    await tester.tap(find.text('Start workout'));
    await settleFrames(tester);
    expect(find.text('Workout Session'), findsOneWidget);
    expect(find.text('Exercise 1 of 5'), findsOneWidget);
    expect(find.text('0 / 15 sets done'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '20');
    await settleFrames(tester, frames: 3);
    await tester.enterText(fields.at(1), '12');
    await settleFrames(tester, frames: 3);

    final checkbox = find.byType(Checkbox).first;
    await tester.ensureVisible(checkbox);
    await settleFrames(tester, frames: 3);
    await tester.tap(checkbox);
    await settleFrames(tester);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    final pause = find.byTooltip('Pause');
    await tester.ensureVisible(pause);
    await settleFrames(tester, frames: 3);
    expect(pause, findsOneWidget, reason: 'rest timer starts after a set is ticked');

    final addSet = find.text('Add set');
    await tester.ensureVisible(addSet);
    await settleFrames(tester, frames: 3);
    await tester.tap(addSet);
    await settleFrames(tester);
    expect(find.byType(Checkbox), findsNWidgets(4));

    // The progress header is at the top of the screen.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await settleFrames(tester);
    expect(find.text('1 / 16 sets done'), findsOneWidget);

    await tester.runAsync(() async {
      final active = (await SessionRepository(db).activeSession())!;
      final set1 = active.exercises.first.sets.first;
      expect(set1.weightKg, 20);
      expect(set1.reps, 12);
      expect(set1.isCompleted, isTrue);
      expect(active.exercises.first.sets.length, 4);
    });
  });

  testWidgets('adding a food updates the diet totals', (tester) async {
    await pumpApp(tester, profile: const UserProfile(name: 'Saransh', calorieTarget: 2200));
    await tester.tap(find.text('Diet'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add food to Breakfast'));
    await tester.pumpAndSettle();
    expect(find.text('Add Food'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'banana');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();
    expect(find.text('1 small banana (101 g)'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Diet / Nutrition'), findsOneWidget);
    expect(find.text('90'), findsOneWidget); // 89 kcal/100 g × 101 g
    expect(find.text('Banana'), findsWidgets);
    expect(find.text('2,110 kcal remaining'), findsOneWidget);
  });

  testWidgets('theme can be switched and is saved', (tester) async {
    final db = await pumpApp(tester);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Theme'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.light);
    await tester.runAsync(() async {
      expect((await SettingsRepository(db).load()).themeMode, ThemeMode.light);
    });
  });

  testWidgets('empty states explain what to do', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('No weigh-ins yet'), findsOneWidget);

    await tester.tap(find.text('Strength'));
    await tester.pumpAndSettle();
    expect(find.text('No strength data yet'), findsOneWidget);
  });

  testWidgets('profile targets can be edited', (tester) async {
    final db = await pumpApp(tester);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saransh Jais'));
    await tester.pumpAndSettle();
    expect(find.text('Profile & Goals'), findsOneWidget);

    final calories = find.widgetWithText(TextFormField, 'Daily calories');
    await tester.scrollUntilVisible(calories, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.enterText(calories, '2400');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final profile = await ProfileRepository(db).load();
      expect(profile.calorieTarget, 2400);
      expect(profile.targetsManual, isTrue);
    });
  });
}
