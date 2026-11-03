import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../features/exercises/exercise.dart';
import '../../features/exercises/muscles.dart';
import '../../features/workout/data/sample_plans.dart';
import '../utils/dates.dart';
import 'seed_data.dart';

/// Owns the SQLite database: schema, migrations and first-launch seeding.
///
/// Schema history:
/// * v1: `exercises` and `completed` (exercise ticked on a date).
/// * v2: full schema. v1 exercises are kept and enriched; v1 completions are
///   converted into completed workout sessions without set details.
/// * v3: `exercises.target_muscles` and `exercises.assist_muscles` (muscle ids
///   from `Muscle`); bundled exercises are filled in from the seed file.
class AppDatabase {
  AppDatabase._(this.db, this.seed);

  final Database db;
  final SeedData seed;

  static const schemaVersion = 3;
  static const fileName = 'myfit_tracker.db';

  /// Tables in foreign-key order: parents before children. Deletes run in
  /// reverse. Backup and restore rely on this order.
  static const tables = [
    'app_settings',
    'user_profile',
    'meal_categories',
    'exercises',
    'workout_plans',
    'workout_plan_days',
    'planned_exercises',
    'workout_sessions',
    'session_exercises',
    'set_logs',
    'food_items',
    'food_servings',
    'saved_meals',
    'saved_meal_items',
    'food_logs',
    'water_logs',
    'body_weight_logs',
    'body_measurements',
    'reminder_settings',
  ];

  static const defaultMealCategories = ['Breakfast', 'Lunch', 'Evening Snack', 'Dinner', 'Other Snacks'];

  static Future<AppDatabase> open({
    required DatabaseFactory factory,
    required String path,
    required SeedData seed,
  }) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createTables(db, includeExercises: true);
          await _seedAll(db, seed);
        },
        onUpgrade: (db, from, to) async {
          // Schema changes first, oldest to newest, then data backfills.
          if (from < 2) await _addV2Schema(db);
          if (from < 3) await _addV3Schema(db);
          if (from < 2) {
            await _seedAll(db, seed);
            await _convertV1Completions(db);
            await db.execute('DROP TABLE IF EXISTS completed');
          } else {
            await syncSeedExercises(db, seed);
          }
        },
      ),
    );
    return AppDatabase._(db, seed);
  }

  Future<void> close() => db.close();

  /// Deletes every record and restores first-launch data.
  Future<void> resetAllData() => db.transaction((txn) async {
    await deleteAllRows(txn);
    await _seedAll(txn, seed);
  });

  static Future<void> deleteAllRows(DatabaseExecutor txn) async {
    for (final table in tables.reversed) {
      await txn.delete(table);
    }
    await txn.execute('DELETE FROM sqlite_sequence');
  }

  // ---------------------------------------------------------------------------
  // Schema

  static const _exercisesTable = '''
    CREATE TABLE exercises(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      muscle TEXT NOT NULL,
      equipment TEXT NOT NULL,
      secondary_muscles TEXT NOT NULL DEFAULT '',
      target_muscles TEXT NOT NULL DEFAULT '',
      assist_muscles TEXT NOT NULL DEFAULT '',
      exercise_type TEXT NOT NULL DEFAULT 'weight_reps',
      description TEXT NOT NULL DEFAULT '',
      instructions TEXT NOT NULL DEFAULT '',
      image_asset TEXT,
      is_custom INTEGER NOT NULL DEFAULT 0,
      is_archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT
    )''';

  static const _otherTables = [
    '''
    CREATE TABLE app_settings(
      id INTEGER PRIMARY KEY CHECK (id = 1),
      theme TEXT NOT NULL DEFAULT 'dark',
      weight_unit TEXT NOT NULL DEFAULT 'kg',
      height_unit TEXT NOT NULL DEFAULT 'cm',
      water_unit TEXT NOT NULL DEFAULT 'ml',
      default_rest_seconds INTEGER NOT NULL DEFAULT 90 CHECK (default_rest_seconds BETWEEN 0 AND 3600),
      glass_size_ml REAL NOT NULL DEFAULT 250 CHECK (glass_size_ml > 0),
      onboarding_completed INTEGER NOT NULL DEFAULT 0
    )''',
    '''
    CREATE TABLE user_profile(
      id INTEGER PRIMARY KEY CHECK (id = 1),
      name TEXT NOT NULL DEFAULT '',
      age INTEGER CHECK (age IS NULL OR age BETWEEN 10 AND 120),
      sex TEXT,
      height_cm REAL CHECK (height_cm IS NULL OR height_cm > 0),
      target_weight_kg REAL CHECK (target_weight_kg IS NULL OR target_weight_kg > 0),
      diet_preference TEXT,
      training_experience TEXT,
      weekly_training_days INTEGER,
      workout_duration_min INTEGER,
      activity_level TEXT,
      goal TEXT,
      calorie_target REAL,
      protein_target REAL,
      carbs_target REAL,
      fat_target REAL,
      water_target_ml REAL,
      targets_manual INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE meal_categories(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE COLLATE NOCASE,
      sort_order INTEGER NOT NULL,
      is_default INTEGER NOT NULL DEFAULT 0
    )''',
    '''
    CREATE TABLE workout_plans(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      is_sample INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE workout_plan_days(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plan_id INTEGER NOT NULL REFERENCES workout_plans(id) ON DELETE CASCADE,
      weekday INTEGER NOT NULL CHECK (weekday BETWEEN 1 AND 7),
      name TEXT NOT NULL DEFAULT '',
      is_rest_day INTEGER NOT NULL DEFAULT 0,
      UNIQUE(plan_id, weekday)
    )''',
    '''
    CREATE TABLE planned_exercises(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plan_day_id INTEGER NOT NULL REFERENCES workout_plan_days(id) ON DELETE CASCADE,
      exercise_id INTEGER NOT NULL REFERENCES exercises(id),
      sort_order INTEGER NOT NULL,
      planned_sets INTEGER NOT NULL DEFAULT 3 CHECK (planned_sets BETWEEN 1 AND 20),
      min_reps INTEGER CHECK (min_reps IS NULL OR min_reps >= 0),
      max_reps INTEGER CHECK (max_reps IS NULL OR max_reps >= 0),
      rest_seconds INTEGER NOT NULL DEFAULT 90 CHECK (rest_seconds BETWEEN 0 AND 3600)
    )''',
    '''
    CREATE TABLE workout_sessions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plan_day_id INTEGER REFERENCES workout_plan_days(id) ON DELETE SET NULL,
      name TEXT NOT NULL,
      date TEXT NOT NULL,
      started_at TEXT NOT NULL,
      completed_at TEXT,
      duration_seconds INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL CHECK (status IN ('in_progress', 'completed')),
      current_index INTEGER NOT NULL DEFAULT 0,
      notes TEXT NOT NULL DEFAULT ''
    )''',
    '''
    CREATE TABLE session_exercises(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
      exercise_id INTEGER NOT NULL REFERENCES exercises(id),
      sort_order INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'skipped')),
      min_reps INTEGER,
      max_reps INTEGER,
      rest_seconds INTEGER NOT NULL DEFAULT 90,
      notes TEXT NOT NULL DEFAULT ''
    )''',
    '''
    CREATE TABLE set_logs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_exercise_id INTEGER NOT NULL REFERENCES session_exercises(id) ON DELETE CASCADE,
      set_number INTEGER NOT NULL,
      weight_kg REAL CHECK (weight_kg IS NULL OR weight_kg >= 0),
      reps INTEGER CHECK (reps IS NULL OR reps >= 0),
      duration_seconds INTEGER CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
      distance_meters REAL CHECK (distance_meters IS NULL OR distance_meters >= 0),
      is_completed INTEGER NOT NULL DEFAULT 0,
      completed_at TEXT
    )''',
    '''
    CREATE TABLE food_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      food_type TEXT NOT NULL DEFAULT 'vegetarian',
      base_unit TEXT NOT NULL CHECK (base_unit IN ('g', 'ml')),
      base_quantity REAL NOT NULL DEFAULT 100 CHECK (base_quantity > 0),
      calories REAL NOT NULL CHECK (calories >= 0),
      protein REAL NOT NULL CHECK (protein >= 0),
      carbohydrates REAL NOT NULL CHECK (carbohydrates >= 0),
      fat REAL NOT NULL CHECK (fat >= 0),
      fiber REAL CHECK (fiber IS NULL OR fiber >= 0),
      preparation_state TEXT NOT NULL DEFAULT 'as_eaten',
      source TEXT NOT NULL DEFAULT '',
      is_estimate INTEGER NOT NULL DEFAULT 1,
      is_custom INTEGER NOT NULL DEFAULT 0,
      is_archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE food_servings(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      food_id INTEGER NOT NULL REFERENCES food_items(id) ON DELETE CASCADE,
      label TEXT NOT NULL,
      quantity REAL NOT NULL CHECK (quantity > 0),
      is_estimate INTEGER NOT NULL DEFAULT 1,
      is_custom INTEGER NOT NULL DEFAULT 0
    )''',
    '''
    CREATE TABLE saved_meals(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE saved_meal_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      saved_meal_id INTEGER NOT NULL REFERENCES saved_meals(id) ON DELETE CASCADE,
      food_id INTEGER NOT NULL REFERENCES food_items(id),
      quantity REAL NOT NULL CHECK (quantity > 0),
      serving_label TEXT,
      serving_count REAL,
      sort_order INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE food_logs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      meal_category TEXT NOT NULL,
      logged_at TEXT NOT NULL,
      source_type TEXT NOT NULL CHECK (source_type IN ('food', 'meal')),
      source_id INTEGER,
      display_name TEXT NOT NULL,
      quantity REAL NOT NULL CHECK (quantity > 0),
      unit TEXT NOT NULL,
      base_quantity REAL,
      calories REAL NOT NULL CHECK (calories >= 0),
      protein REAL NOT NULL CHECK (protein >= 0),
      carbohydrates REAL NOT NULL CHECK (carbohydrates >= 0),
      fat REAL NOT NULL CHECK (fat >= 0),
      fiber REAL,
      fiber_missing INTEGER NOT NULL DEFAULT 0,
      detail TEXT,
      notes TEXT NOT NULL DEFAULT ''
    )''',
    '''
    CREATE TABLE water_logs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      logged_at TEXT NOT NULL,
      quantity_ml REAL NOT NULL CHECK (quantity_ml > 0)
    )''',
    '''
    CREATE TABLE body_weight_logs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL UNIQUE,
      weight_kg REAL NOT NULL CHECK (weight_kg > 0),
      notes TEXT NOT NULL DEFAULT ''
    )''',
    '''
    CREATE TABLE body_measurements(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      measurement_type TEXT NOT NULL,
      value_cm REAL NOT NULL CHECK (value_cm > 0),
      notes TEXT NOT NULL DEFAULT ''
    )''',
    '''
    CREATE TABLE reminder_settings(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      reminder_type TEXT NOT NULL UNIQUE,
      enabled INTEGER NOT NULL DEFAULT 0,
      hour INTEGER NOT NULL CHECK (hour BETWEEN 0 AND 23),
      minute INTEGER NOT NULL CHECK (minute BETWEEN 0 AND 59),
      configuration TEXT
    )''',
    'CREATE INDEX idx_exercises_muscle ON exercises(muscle)',
    'CREATE INDEX idx_planned_exercises_day ON planned_exercises(plan_day_id, sort_order)',
    'CREATE INDEX idx_sessions_date ON workout_sessions(date)',
    'CREATE INDEX idx_sessions_status ON workout_sessions(status)',
    'CREATE INDEX idx_session_exercises_session ON session_exercises(session_id, sort_order)',
    'CREATE INDEX idx_session_exercises_exercise ON session_exercises(exercise_id)',
    'CREATE INDEX idx_set_logs_session_exercise ON set_logs(session_exercise_id, set_number)',
    'CREATE INDEX idx_food_items_name ON food_items(name COLLATE NOCASE)',
    'CREATE INDEX idx_food_servings_food ON food_servings(food_id)',
    'CREATE INDEX idx_saved_meal_items_meal ON saved_meal_items(saved_meal_id, sort_order)',
    'CREATE INDEX idx_food_logs_date ON food_logs(date)',
    'CREATE INDEX idx_water_logs_date ON water_logs(date)',
    'CREATE INDEX idx_measurements_type_date ON body_measurements(measurement_type, date)',
  ];

  static Future<void> _createTables(DatabaseExecutor db, {required bool includeExercises}) async {
    if (includeExercises) await db.execute(_exercisesTable);
    for (final ddl in _otherTables) {
      await db.execute(ddl);
    }
  }

  // ---------------------------------------------------------------------------
  // Seeding

  static Future<void> _seedAll(DatabaseExecutor db, SeedData seed) async {
    await _seedDefaults(db);
    await syncSeedExercises(db, seed);
    await _seedFoods(db, seed);
    await SamplePlans.insert(db, days: SamplePlans.defaultDays, active: true);
  }

  static Future<void> _seedDefaults(DatabaseExecutor db) async {
    final now = timestampNow();
    await db.insert('app_settings', {'id': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('user_profile', {
      'id': 1,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    for (var i = 0; i < defaultMealCategories.length; i++) {
      await db.insert('meal_categories', {
        'name': defaultMealCategories[i],
        'sort_order': i,
        'is_default': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final reminders = [
      {'reminder_type': 'workout', 'hour': 18, 'minute': 0},
      {'reminder_type': 'meal', 'hour': 21, 'minute': 0},
      {
        'reminder_type': 'water',
        'hour': 10,
        'minute': 0,
        'configuration': jsonEncode({'intervalHours': 2, 'endHour': 20}),
      },
      {'reminder_type': 'weight', 'hour': 7, 'minute': 30},
    ];
    for (final r in reminders) {
      await db.insert('reminder_settings', {...r, 'enabled': 0}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Inserts bundled exercises. A non-custom exercise that already exists
  /// with the same name (from an older version or backup) gets its details
  /// refreshed instead, so its id and history are kept. Custom exercises are
  /// never touched.
  static Future<void> syncSeedExercises(DatabaseExecutor db, SeedData seed) async {
    final existing = await db.query('exercises', columns: ['id', 'name', 'is_custom']);
    final byName = {for (final r in existing) (r['name'] as String).toLowerCase(): r};
    final now = timestampNow();
    for (final e in seed.exercises) {
      final targets = Muscle.parse((e['targets'] as List? ?? const []).join(','));
      final assists = Muscle.parse((e['assists'] as List? ?? const []).join(','));
      final values = {
        'name': e['name'],
        'muscle': e['muscle'],
        'equipment': e['equipment'],
        'secondary_muscles': Exercise.secondaryGroupsFor(e['muscle'] as String, assists).join(','),
        'target_muscles': Muscle.encode(targets),
        'assist_muscles': Muscle.encode(assists),
        'exercise_type': e['type'] ?? 'weight_reps',
        'description': e['description'] ?? '',
        'instructions': (e['instructions'] as List? ?? const []).join('\n'),
      };
      final match = byName[(e['name'] as String).toLowerCase()];
      if (match == null) {
        await db.insert('exercises', {...values, 'is_custom': 0, 'is_archived': 0, 'created_at': now});
      } else if (match['is_custom'] == 0) {
        await db.update('exercises', values, where: 'id = ?', whereArgs: [match['id']]);
      }
    }
  }

  static Future<void> _seedFoods(DatabaseExecutor db, SeedData seed) async {
    final now = timestampNow();
    for (final f in seed.foods) {
      final sourceKey = f['source'] as String;
      final foodId = await db.insert('food_items', {
        'name': f['name'],
        'category': f['category'],
        'food_type': 'vegetarian',
        'base_unit': f['unit'],
        'base_quantity': 100,
        'calories': f['kcal'],
        'protein': f['protein'],
        'carbohydrates': f['carbs'],
        'fat': f['fat'],
        'fiber': f['fiber'],
        'preparation_state': f['state'] ?? 'as_eaten',
        'source': seed.foodSources[sourceKey] ?? sourceKey,
        'is_estimate': sourceKey == 'usda' ? 0 : 1,
        'is_custom': 0,
        'created_at': now,
        'updated_at': now,
      });
      for (final s in (f['servings'] as List? ?? const [])) {
        final serving = s as List;
        await db.insert('food_servings', {
          'food_id': foodId,
          'label': serving[0],
          'quantity': serving[1],
          'is_estimate': serving[2] == true ? 1 : 0,
          'is_custom': 0,
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Migrations

  /// v1 → v2 schema: richer exercises plus every other table.
  static Future<void> _addV2Schema(Database db) async {
    const newColumns = [
      "secondary_muscles TEXT NOT NULL DEFAULT ''",
      "exercise_type TEXT NOT NULL DEFAULT 'weight_reps'",
      "description TEXT NOT NULL DEFAULT ''",
      "instructions TEXT NOT NULL DEFAULT ''",
      'image_asset TEXT',
      'is_custom INTEGER NOT NULL DEFAULT 0',
      'is_archived INTEGER NOT NULL DEFAULT 0',
      'created_at TEXT',
    ];
    for (final column in newColumns) {
      await db.execute('ALTER TABLE exercises ADD COLUMN $column');
    }
    await db.execute("UPDATE exercises SET is_custom = 1 WHERE equipment = 'Custom'");
    await db.execute("UPDATE exercises SET exercise_type = 'bodyweight_reps' WHERE equipment = 'Bodyweight'");
    await db.update('exercises', {'created_at': timestampNow()});
    await _createTables(db, includeExercises: false);
  }

  /// v2 → v3 schema: specific muscles per exercise.
  static Future<void> _addV3Schema(Database db) async {
    await db.execute("ALTER TABLE exercises ADD COLUMN target_muscles TEXT NOT NULL DEFAULT ''");
    await db.execute("ALTER TABLE exercises ADD COLUMN assist_muscles TEXT NOT NULL DEFAULT ''");
  }

  /// v1 only recorded "exercise X was done on date Y". Each date becomes one
  /// completed session with no set details, clearly labelled as imported.
  static Future<void> _convertV1Completions(Database db) async {
    final hasTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'completed'");
    if (hasTable.isEmpty) return;
    final rows = await db.rawQuery(
      'SELECT c.exerciseId AS exercise_id, c.date AS date FROM completed c '
      'JOIN exercises e ON e.id = c.exerciseId ORDER BY c.date, c.exerciseId',
    );
    final byDate = <String, List<int>>{};
    for (final r in rows) {
      byDate.putIfAbsent(r['date'] as String, () => []).add(r['exercise_id'] as int);
    }
    for (final entry in byDate.entries) {
      final noon = parseDateKey(entry.key).add(const Duration(hours: 12)).toUtc().toIso8601String();
      final sessionId = await db.insert('workout_sessions', {
        'name': 'Logged workout',
        'date': entry.key,
        'started_at': noon,
        'completed_at': noon,
        'duration_seconds': 0,
        'status': 'completed',
        'notes': 'Imported from an earlier app version: exercises were ticked as done without set details.',
      });
      var order = 0;
      for (final exerciseId in entry.value) {
        await db.insert('session_exercises', {
          'session_id': sessionId,
          'exercise_id': exerciseId,
          'sort_order': order++,
          'status': 'completed',
        });
      }
    }
  }
}
