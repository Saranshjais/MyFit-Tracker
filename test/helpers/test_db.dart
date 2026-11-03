import 'dart:io';

import 'package:myfit_tracker/core/database/app_database.dart';
import 'package:myfit_tracker/core/database/seed_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Seed data read straight from the asset files.
SeedData loadSeed() => SeedData.fromJson(
  File('assets/data/exercises.json').readAsStringSync(),
  File('assets/data/foods.json').readAsStringSync(),
);

/// Runs SQLite in-process so database futures complete without real I/O
/// waits, which also works inside widget tests' fake async zone.
DatabaseFactory get testDatabaseFactory {
  sqfliteFfiInit();
  return databaseFactoryFfiNoIsolate;
}

Future<AppDatabase> openTestDatabase({String path = inMemoryDatabasePath}) =>
    AppDatabase.open(factory: testDatabaseFactory, path: path, seed: loadSeed());

/// A fresh temporary file path for tests that reopen the database.
String tempDatabasePath(String name) {
  final dir = Directory.systemTemp.createTempSync('myfit_test_');
  return '${dir.path}${Platform.pathSeparator}$name.db';
}
