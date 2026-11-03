import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/core/database/app_database.dart';
import 'package:myfit_tracker/features/backup/backup_service.dart';
import 'package:myfit_tracker/features/exercises/exercise.dart';
import 'package:myfit_tracker/features/exercises/exercise_repository.dart';
import 'package:myfit_tracker/features/exercises/muscles.dart';
import 'package:myfit_tracker/features/nutrition/food_log_repository.dart';
import 'package:myfit_tracker/features/nutrition/food_repository.dart';
import 'package:myfit_tracker/features/nutrition/meal_repository.dart';
import 'package:myfit_tracker/features/nutrition/nutrition_models.dart';
import 'package:myfit_tracker/features/progress/body_repository.dart';
import 'package:myfit_tracker/features/water/water_repository.dart';
import 'package:myfit_tracker/features/workout/models.dart';
import 'package:myfit_tracker/features/workout/plan_repository.dart';
import 'package:myfit_tracker/features/workout/session_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late PlanRepository plans;
  late SessionRepository sessions;
  late ExerciseRepository exercises;
  late FoodRepository foods;
  late FoodLogRepository logs;
  late MealRepository meals;
  late BodyRepository body;

  setUp(() async {
    db = await openTestDatabase();
    plans = PlanRepository(db);
    sessions = SessionRepository(db);
    exercises = ExerciseRepository(db);
    foods = FoodRepository(db);
    logs = FoodLogRepository(db);
    meals = MealRepository(db, foods);
    body = BodyRepository(db);
  });

  tearDown(() => db.close());

  Future<Exercise> exercise(String name) async => (await exercises.all()).firstWhere((e) => e.name == name);
  Future<FoodItem> food(String name) async => (await foods.search(query: name)).firstWhere((f) => f.name == name);

  test('a fresh database has seed data and defaults', () async {
    final seed = loadSeed();
    expect((await exercises.all()).length, seed.exercises.length);
    expect((await foods.search(limit: 1000)).length, seed.foods.length);
    final plan = (await plans.activePlan())!;
    expect(plan.plan.isSample, isTrue);
    expect(plan.days.length, 7);
    expect(plan.trainingDays, 6);
    expect(await logs.mealCategories(), AppDatabase.defaultMealCategories);
    final bench = await exercise('Bench Press');
    expect(bench.targetMuscles, [Muscle.chest]);
    expect(bench.assistMuscles, containsAll([Muscle.frontDelts, Muscle.triceps]));
    expect(bench.secondaryMuscles, containsAll(['Shoulders', 'Arms']));
    expect((await exercises.all()).every((e) => e.targetMuscles.isNotEmpty), isTrue);
  });

  test('custom exercises keep the muscles chosen for them', () async {
    final id = await exercises.create(
      const Exercise(
        id: 0,
        name: 'Landmine Press',
        muscle: 'Shoulders',
        equipment: 'Barbell',
        targetMuscles: [Muscle.frontDelts, Muscle.chestUpper],
        assistMuscles: [Muscle.triceps],
      ),
    );
    final e = (await exercises.byId(id))!;
    expect(e.targetMuscles, [Muscle.frontDelts, Muscle.chestUpper]);
    expect(e.assistMuscles, [Muscle.triceps]);
  });

  test('paneer, low-fat paneer and tofu have different values', () async {
    final a = await food('Paneer (full fat)');
    final b = await food('Low-fat paneer');
    final c = await food('Tofu (firm)');
    expect({a.per.calories, b.per.calories, c.per.calories}.length, 3);
    expect({a.per.fat, b.per.fat, c.per.fat}.length, 3);
  });

  group('plans', () {
    test('create, add exercises, reorder, copy and delete', () async {
      final id = await plans.createPlan('My split');
      await plans.setActive(id);
      var plan = (await plans.planWithDays(id))!;
      expect(plan.days.every((d) => d.isRestDay), isTrue);

      final monday = plan.dayFor(1);
      final bench = await exercise('Bench Press');
      final row = await exercise('Barbell Row');
      final a = await plans.addExercise(monday.id, bench.id);
      final b = await plans.addExercise(monday.id, row.id);
      plan = (await plans.planWithDays(id))!;
      expect(plan.dayFor(1).isRestDay, isFalse, reason: 'adding an exercise makes it a training day');
      expect(plan.dayFor(1).exercises.map((e) => e.id), [a, b]);

      await plans.reorder(monday.id, [b, a]);
      expect((await plans.day(monday.id))!.exercises.map((e) => e.id), [b, a]);

      await plans.updatePlannedExercise(a, sets: 5, minReps: 3, maxReps: 5, restSeconds: 180);
      final updated = (await plans.day(monday.id))!.exercises.firstWhere((e) => e.id == a);
      expect(updated.sets, 5);
      expect(updated.restSeconds, 180);
      expect(
        () => plans.updatePlannedExercise(a, sets: 3, minReps: 12, maxReps: 8, restSeconds: 60),
        throwsArgumentError,
      );
      expect(() => plans.updatePlannedExercise(a, sets: 0, restSeconds: 60), throwsArgumentError);

      final thursday = plan.dayFor(4);
      await plans.copyDay(monday.id, thursday.id);
      expect((await plans.day(thursday.id))!.exercises.length, 2);

      final copyId = await plans.duplicatePlan(id);
      expect((await plans.planWithDays(copyId))!.dayFor(4).exercises.length, 2);

      await plans.deletePlan(id);
      expect((await plans.activePlan())!.plan.id, isNot(id), reason: 'another plan becomes active');
    });

    test('only one plan is active', () async {
      final a = await plans.createPlan('A');
      final b = await plans.createPlan('B');
      await plans.setActive(a);
      await plans.setActive(b);
      final all = await plans.plans();
      expect(all.where((p) => p.isActive).map((p) => p.id), [b]);
    });

    test('sample plan can be replaced with fewer training days', () async {
      await plans.replaceSamplePlan(3);
      final plan = (await plans.activePlan())!;
      expect(plan.trainingDays, 3);
      expect(plan.plan.isSample, isTrue);
    });
  });

  group('workout sessions', () {
    Future<PlanDay> monday() async => (await plans.activePlan())!.dayFor(1);

    test('start, log sets, finish', () async {
      final day = await monday();
      final id = await sessions.startFromPlanDay(day, date: '2026-11-02');
      expect(await sessions.startFromPlanDay(day, date: '2026-11-02'), id, reason: 'no duplicate sessions');

      var s = (await sessions.byId(id))!;
      expect(s.exercises.length, day.exercises.length);
      expect(s.exercises.first.sets.length, day.exercises.first.sets);
      expect(s.exercises.first.sets.every((x) => !x.isCompleted), isTrue);

      final first = s.exercises.first;
      await sessions.updateSetValues(first.sets[0].id, const SetValues(weightKg: 20, reps: 12));
      await sessions.setCompleted(first.sets[0].id, true);
      await sessions.updateSetValues(first.sets[1].id, const SetValues(weightKg: 25, reps: 10));
      await sessions.setCompleted(first.sets[1].id, true);
      expect(
        () => sessions.updateSetValues(first.sets[2].id, const SetValues(weightKg: -5, reps: 5)),
        throwsArgumentError,
      );

      final added = await sessions.addSet(first.id);
      s = (await sessions.byId(id))!;
      final addedSet = s.exercises.first.sets.firstWhere((x) => x.id == added);
      expect(addedSet.setNumber, 4);
      expect(addedSet.isCompleted, isFalse, reason: 'copied values are never auto-completed');

      await sessions.removeSet(first.sets[2].id);
      s = (await sessions.byId(id))!;
      expect(s.exercises.first.sets.map((x) => x.setNumber), [1, 2, 3]);

      await sessions.finish(id);
      s = (await sessions.byId(id))!;
      expect(s.status, SessionStatus.completed);
      expect(s.completedAt, isNotNull);
      expect(s.exercises.first.sets.length, 2, reason: 'unticked sets are dropped');
      expect(s.exercises.first.status, SessionExerciseStatus.completed);
      expect(s.exercises.last.status, SessionExerciseStatus.skipped);

      final history = await sessions.history();
      expect(history.single.volumeKg, 20 * 12 + 25 * 10);
      expect(history.single.setCount, 2);
      expect(await sessions.completedDates('2026-11-02', '2026-11-08'), {'2026-11-02'});
    });

    test('next session is pre-filled from the previous one', () async {
      final day = await monday();
      final id = await sessions.startFromPlanDay(day, date: '2026-11-02');
      final s = (await sessions.byId(id))!;
      final set1 = s.exercises.first.sets.first;
      await sessions.updateSetValues(set1.id, const SetValues(weightKg: 40, reps: 8));
      await sessions.setCompleted(set1.id, true);
      await sessions.finish(id);

      final next = await sessions.startFromPlanDay(day, date: '2026-11-09');
      final n = (await sessions.byId(next))!;
      expect(n.exercises.first.sets.first.weightKg, 40);
      expect(n.exercises.first.sets.first.reps, 8);
      expect(n.exercises.first.sets.first.isCompleted, isFalse);
      expect((await sessions.previousSets(s.exercises.first.exercise.id, excludeSessionId: next)).single.weightKg, 40);
    });

    test('replace, skip and discard', () async {
      final id = await sessions.startEmpty(date: '2026-11-03');
      final bench = await exercise('Bench Press');
      final squat = await exercise('Squat');
      await sessions.addExercise(id, bench);
      var s = (await sessions.byId(id))!;
      await sessions.replaceExercise(s.exercises.single.id, squat);
      s = (await sessions.byId(id))!;
      expect(s.exercises.single.exercise.name, 'Squat');
      expect(s.exercises.single.sets.length, 3);

      await sessions.setExerciseStatus(s.exercises.single.id, SessionExerciseStatus.skipped);
      expect((await sessions.byId(id))!.exercises.single.status, SessionExerciseStatus.skipped);

      await sessions.delete(id);
      expect(await sessions.byId(id), isNull);
      expect(await sessions.activeSession(), isNull);
    });

    test('exercises used in history are archived, not deleted', () async {
      final id = await sessions.startEmpty(date: '2026-11-03');
      final bench = await exercise('Bench Press');
      await sessions.addExercise(id, bench);
      expect(await exercises.deleteOrArchive(bench.id), isTrue);
      expect((await exercises.all()).any((e) => e.id == bench.id), isFalse);
      expect((await sessions.byId(id))!.exercises.single.exercise.name, 'Bench Press');

      final customId = await exercises.create(
        const Exercise(id: 0, name: 'My move', muscle: 'Core', equipment: 'Other'),
      );
      expect(await exercises.deleteOrArchive(customId), isFalse);
      expect(await exercises.byId(customId), isNull);
    });

    test('renaming an exercise keeps its history', () async {
      final id = await sessions.startEmpty(date: '2026-11-03');
      final bench = await exercise('Bench Press');
      await sessions.addExercise(id, bench);
      await exercises.update(
        Exercise(id: bench.id, name: 'Flat Bench', muscle: bench.muscle, equipment: bench.equipment),
      );
      expect((await sessions.byId(id))!.exercises.single.exercise.name, 'Flat Bench');
    });
  });

  group('food logging', () {
    test('logs keep their values when the food is corrected later', () async {
      final roti = await food('Roti (whole wheat, no ghee)');
      final portion = FoodPortion(food: roti, serving: roti.servings[1], count: 2); // 2 × 40 g
      final id = await logs.logFood(date: '2026-11-03', category: 'Lunch', portion: portion);
      final before = (await logs.forDate('2026-11-03')).single;
      expect(before.nutrients.calories, closeTo(255 * 0.8, 1e-9));
      expect(before.baseQuantity, 80);

      await foods.update(
        FoodItem(
          id: roti.id,
          name: roti.name,
          category: roti.category,
          per: const Nutrients(calories: 300, protein: 10, carbs: 55, fat: 4, fiber: 8),
          servings: roti.servings,
        ),
      );
      final after = (await logs.forDate('2026-11-03')).single;
      expect(after.nutrients.calories, before.nutrients.calories);

      await logs.updateQuantity(id, 3);
      final edited = (await logs.forDate('2026-11-03')).single;
      expect(
        edited.nutrients.calories,
        closeTo(255 * 1.2, 1e-9),
        reason: 'scaled from the snapshot, not the new food values',
      );
      expect(edited.baseQuantity, closeTo(120, 1e-9));

      await logs.updateCategory(id, 'Dinner');
      expect((await logs.forDate('2026-11-03')).single.mealCategory, 'Dinner');
      await logs.delete(id);
      expect(await logs.forDate('2026-11-03'), isEmpty);
    });

    test('daily totals sum each day separately', () async {
      final rice = await food('Cooked white rice');
      final dal = await food('Toor dal (cooked, tempered)');
      await logs.logFood(
        date: '2026-11-02',
        category: 'Lunch',
        portion: FoodPortion(food: rice, count: 150),
      );
      await logs.logFood(
        date: '2026-11-03',
        category: 'Lunch',
        portion: FoodPortion(food: rice, count: 100),
      );
      await logs.logFood(
        date: '2026-11-03',
        category: 'Lunch',
        portion: FoodPortion(food: dal, count: 150),
      );
      final totals = await logs.dailyTotals('2026-11-01', '2026-11-03');
      expect(totals.keys, containsAll(['2026-11-02', '2026-11-03']));
      expect(totals['2026-11-02']!.calories, closeTo(195, 1e-9));
      expect(totals['2026-11-03']!.calories, closeTo(130 + 165, 1e-9));
      expect(totals.containsKey('2026-11-01'), isFalse, reason: 'days without entries are not zero-filled');
    });

    test('quantities must be positive', () async {
      final rice = await food('Cooked white rice');
      expect(
        () => logs.logFood(
          date: '2026-11-03',
          category: 'Lunch',
          portion: FoodPortion(food: rice, count: 0),
        ),
        throwsArgumentError,
      );
    });

    test('custom foods validate their values', () async {
      expect(
        () => foods.create(const FoodItem(id: 0, name: 'Bad', category: 'Other', per: Nutrients(calories: -10))),
        throwsArgumentError,
      );
      final id = await foods.create(
        const FoodItem(
          id: 0,
          name: 'Besan chilla',
          category: 'Breakfast Dishes',
          per: Nutrients(calories: 180, protein: 9, carbs: 22, fat: 6, fiberMissing: 1),
          servings: [FoodServing(label: '1 chilla (70 g)', quantity: 70)],
        ),
      );
      final created = (await foods.byId(id))!;
      expect(created.isCustom, isTrue);
      expect(created.per.fiber, isNull);
      expect(created.servings.single.quantity, 70);
    });
  });

  group('saved meals', () {
    test('save, reload, duplicate; editing does not change past logs', () async {
      final roti = await food('Roti (whole wheat, no ghee)');
      final dal = await food('Toor dal (cooked, tempered)');
      final items = [
        SavedMealItem(
          portion: FoodPortion(food: roti, serving: roti.servings[1], count: 3),
        ),
        SavedMealItem(portion: FoodPortion(food: dal, count: 150)),
      ];
      final id = await meals.save(SavedMeal(name: 'Usual lunch', category: 'Lunch', items: items));
      final loaded = (await meals.byId(id))!;
      expect(loaded.items.length, 2);
      expect(loaded.items.first.portion.count, 3);
      expect(loaded.items.first.portion.serving!.label, roti.servings[1].label);
      final total = loaded.nutrients.calories;
      expect(total, closeTo(255 * 1.2 + 110 * 1.5, 1e-9));

      await logs.logMeal(
        date: '2026-11-03',
        category: 'Lunch',
        name: loaded.name,
        items: loaded.items.map((i) => i.portion).toList(),
        servings: 2,
        savedMealId: id,
      );
      final logged = (await logs.forDate('2026-11-03')).single;
      expect(logged.nutrients.calories, closeTo(total * 2, 1e-9), reason: 'multiplied by servings once');
      expect(logged.ingredients.length, 2);

      await meals.save(SavedMeal(id: id, name: 'Usual lunch', category: 'Lunch', items: [items.first]));
      expect((await logs.forDate('2026-11-03')).single.nutrients.calories, closeTo(total * 2, 1e-9));

      final copy = await meals.duplicate(id);
      expect((await meals.byId(copy))!.name, 'Usual lunch (copy)');
      expect(() => meals.save(const SavedMeal(name: 'Empty', category: 'Lunch')), throwsArgumentError);
    });
  });

  group('body tracking', () {
    test('one weigh-in per date', () async {
      await body.recordWeight('2026-11-01', 64);
      await body.recordWeight('2026-11-01', 64.4);
      await body.recordWeight('2026-11-03', 64.2);
      final all = await body.weights();
      expect(all.map((w) => w.weightKg), [64.4, 64.2]);
      expect(() => body.updateWeight(all.last.id, date: '2026-11-01', kg: 64), throwsA(isA<DuplicateDateException>()));
      expect(() => body.recordWeight('2026-11-04', -2), throwsArgumentError);
      await body.deleteWeight(all.first.id);
      expect((await body.latestWeight())!.date, '2026-11-03');
    });

    test('measurements are stored in cm', () async {
      final id = await body.addMeasurement(date: '2026-11-03', type: 'Waist', valueCm: 76);
      final m = (await body.measurements()).single;
      expect(m.id, id);
      expect(m.valueCm, 76);
      await body.deleteMeasurement(id);
      expect(await body.measurements(), isEmpty);
    });

    test('water entries can be added and undone', () async {
      final water = WaterRepository(db);
      final id = await water.add('2026-11-03', 250);
      await water.add('2026-11-03', 500);
      await water.delete(id);
      expect((await water.forDate('2026-11-03')).single.ml, 500);
      expect(() => water.add('2026-11-03', 0), throwsArgumentError);
    });
  });

  test('data persists after closing and reopening the database', () async {
    final path = tempDatabasePath('persist');
    var fileDb = await openTestDatabase(path: path);
    await BodyRepository(fileDb).recordWeight('2026-11-03', 70);
    await fileDb.close();
    fileDb = await openTestDatabase(path: path);
    expect((await BodyRepository(fileDb).weights()).single.weightKg, 70);
    expect((await ExerciseRepository(fileDb).all()).length, loadSeed().exercises.length, reason: 'not seeded twice');
    await fileDb.close();
  });

  group('backup', () {
    test('export then import restores the same data', () async {
      await body.recordWeight('2026-11-03', 64.2);
      final day = (await plans.activePlan())!.dayFor(1);
      final sid = await sessions.startFromPlanDay(day, date: '2026-11-02');
      final s = (await sessions.byId(sid))!;
      await sessions.updateSetValues(s.exercises.first.sets.first.id, const SetValues(weightKg: 30, reps: 10));
      await sessions.setCompleted(s.exercises.first.sets.first.id, true);
      await sessions.finish(sid);

      final json = await BackupService(db).exportJson();

      final other = await openTestDatabase();
      await BodyRepository(other).recordWeight('2026-01-01', 99);
      await BackupService(other).import(jsonDecode(json));
      expect((await BodyRepository(other).weights()).single.weightKg, 64.2);
      final history = await SessionRepository(other).history();
      expect(history.single.volumeKg, 300);
      await other.close();
    });

    test('an invalid backup is rejected and existing data kept', () async {
      await body.recordWeight('2026-11-03', 64.2);
      final service = BackupService(db);
      await expectLater(service.import({'format': 'something-else'}), throwsA(isA<BackupException>()));
      await expectLater(service.import('not even a map'), throwsA(isA<BackupException>()));
      expect((await body.weights()).single.weightKg, 64.2);
    });

    test('a backup whose records do not fit together is rolled back', () async {
      await body.recordWeight('2026-11-03', 64.2);
      final service = BackupService(db);
      final data = await service.export();
      final tables = data['tables'] as Map<String, Object?>;
      // A set that points at a session exercise that does not exist.
      tables['set_logs'] = [
        {'id': 1, 'session_exercise_id': 999, 'set_number': 1, 'weight_kg': 10, 'reps': 5, 'is_completed': 1},
      ];
      await expectLater(service.import(jsonDecode(jsonEncode(data))), throwsA(isA<BackupException>()));
      expect((await body.weights()).single.weightKg, 64.2);
      expect((await exercises.all()).length, loadSeed().exercises.length);
    });

    test('validation reports what is wrong', () async {
      final service = BackupService(db);
      final cols = await service.columns();
      final data = await service.export();
      expect(BackupService.validate(data, cols).isValid, isTrue);
      final newer = {...data, 'schemaVersion': AppDatabase.schemaVersion + 1};
      expect(BackupService.validate(newer, cols).errors.single, contains('newer version'));
      final missing = {
        ...data,
        'tables': {...(data['tables'] as Map)}..remove('food_logs'),
      };
      expect(BackupService.validate(missing, cols).errors.single, contains('food_logs'));
    });
  });

  test('reset deletes user data and restores first-launch data', () async {
    await body.recordWeight('2026-11-03', 64.2);
    await db.db.update('app_settings', {'onboarding_completed': 1});
    await db.resetAllData();
    expect(await body.weights(), isEmpty);
    final settings = (await db.db.query('app_settings')).single;
    expect(settings['onboarding_completed'], 0);
    expect((await exercises.all()).length, loadSeed().exercises.length);
    expect(await plans.activePlan(), isNotNull);
  });

  test('upgrades a version 1 database without losing data', () async {
    final path = tempDatabasePath('v1');
    final v1 = await testDatabaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, _) async {
          await d.execute(
            'CREATE TABLE exercises(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, muscle TEXT, equipment TEXT)',
          );
          await d.execute('CREATE TABLE completed(exerciseId INTEGER, date TEXT, UNIQUE(exerciseId,date))');
          await d.insert('exercises', {'name': 'Bench Press', 'muscle': 'Chest', 'equipment': 'Barbell'});
          await d.insert('exercises', {'name': 'Plank', 'muscle': 'Core', 'equipment': 'Bodyweight'});
          await d.insert('exercises', {'name': 'Cossack Squat', 'muscle': 'Legs', 'equipment': 'Custom'});
          await d.insert('completed', {'exerciseId': 1, 'date': '2026-10-25'});
          await d.insert('completed', {'exerciseId': 3, 'date': '2026-10-25'});
          await d.insert('completed', {'exerciseId': 2, 'date': '2026-10-26'});
        },
      ),
    );
    await v1.close();

    final upgraded = await openTestDatabase(path: path);
    final ex = ExerciseRepository(upgraded);
    final bench = (await ex.byId(1))!;
    expect(bench.name, 'Bench Press');
    expect(bench.instructions, isNotEmpty, reason: 'details filled in from the seed');
    expect(bench.targetMuscles, [Muscle.chest]);
    expect((await ex.byId(2))!.type, ExerciseType.time);
    final custom = (await ex.byId(3))!;
    expect(custom.isCustom, isTrue);
    expect((await ex.all()).where((e) => e.name == 'Bench Press').length, 1, reason: 'no duplicates');

    final history = await SessionRepository(upgraded).history();
    expect(history.length, 2);
    final oct25 = history.firstWhere((h) => h.date == '2026-10-25');
    expect(oct25.exerciseCount, 2);
    final tables = await upgraded.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'completed'",
    );
    expect(tables, isEmpty);
    expect(await PlanRepository(upgraded).activePlan(), isNotNull);
    await upgraded.close();
  });

  test('upgrades a version 2 database by adding muscle details', () async {
    final path = tempDatabasePath('v2');
    var current = await openTestDatabase(path: path);
    final customId = await ExerciseRepository(current)
        .create(const Exercise(id: 0, name: 'My move', muscle: 'Core', equipment: 'Other'));
    await BodyRepository(current).recordWeight('2026-11-03', 70);
    await current.close();

    // Turn it back into a version 2 database.
    final raw = await testDatabaseFactory.openDatabase(path);
    await raw.execute('ALTER TABLE exercises DROP COLUMN target_muscles');
    await raw.execute('ALTER TABLE exercises DROP COLUMN assist_muscles');
    await raw.setVersion(2);
    await raw.close();

    current = await openTestDatabase(path: path);
    final repo = ExerciseRepository(current);
    final all = await repo.all();
    expect(all.length, loadSeed().exercises.length + 1, reason: 'no duplicates');
    expect(all.firstWhere((e) => e.name == 'Squat').targetMuscles, [Muscle.quads, Muscle.glutes]);
    expect((await repo.byId(customId))!.targetMuscles, isEmpty, reason: 'custom exercises are left alone');
    expect((await BodyRepository(current).weights()).single.weightKg, 70);
    await current.close();
  });

  test('restoring a backup from before muscle details fills them in', () async {
    // Rows from the database are read-only; work on a JSON copy.
    final data = jsonDecode(jsonEncode(await BackupService(db).export())) as Map<String, dynamic>;
    data['schemaVersion'] = 2;
    for (final row in (data['tables'] as Map)['exercises'] as List) {
      (row as Map)
        ..remove('target_muscles')
        ..remove('assist_muscles');
    }
    final other = await openTestDatabase();
    await BackupService(other).import(jsonDecode(jsonEncode(data)));
    final bench = (await ExerciseRepository(other).all()).firstWhere((e) => e.name == 'Bench Press');
    expect(bench.targetMuscles, [Muscle.chest]);
    await other.close();
  });
}
