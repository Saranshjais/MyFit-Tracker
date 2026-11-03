import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/core_providers.dart';
import '../../core/utils/units.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.weightUnit = WeightUnit.kg,
    this.lengthUnit = LengthUnit.cm,
    this.waterUnit = WaterUnit.ml,
    this.defaultRestSeconds = 90,
    this.glassSizeMl = 250,
    this.onboardingCompleted = false,
  });

  final ThemeMode themeMode;
  final WeightUnit weightUnit;
  final LengthUnit lengthUnit;
  final WaterUnit waterUnit;
  final int defaultRestSeconds;

  /// Size of one "glass" for quick water logging.
  final double glassSizeMl;
  final bool onboardingCompleted;

  factory AppSettings.fromMap(Map<String, Object?> m) => AppSettings(
    themeMode: switch (m['theme']) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    },
    weightUnit: m['weight_unit'] == 'lb' ? WeightUnit.lb : WeightUnit.kg,
    lengthUnit: m['height_unit'] == 'ft_in' ? LengthUnit.ftIn : LengthUnit.cm,
    waterUnit: m['water_unit'] == 'fl_oz' ? WaterUnit.flOz : WaterUnit.ml,
    defaultRestSeconds: (m['default_rest_seconds'] as int?) ?? 90,
    glassSizeMl: (m['glass_size_ml'] as num?)?.toDouble() ?? 250,
    onboardingCompleted: m['onboarding_completed'] == 1,
  );

  Map<String, Object?> toMap() => {
    'theme': switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    },
    'weight_unit': weightUnit == WeightUnit.lb ? 'lb' : 'kg',
    'height_unit': lengthUnit == LengthUnit.ftIn ? 'ft_in' : 'cm',
    'water_unit': waterUnit == WaterUnit.flOz ? 'fl_oz' : 'ml',
    'default_rest_seconds': defaultRestSeconds,
    'glass_size_ml': glassSizeMl,
    'onboarding_completed': onboardingCompleted ? 1 : 0,
  };

  AppSettings copyWith({
    ThemeMode? themeMode,
    WeightUnit? weightUnit,
    LengthUnit? lengthUnit,
    WaterUnit? waterUnit,
    int? defaultRestSeconds,
    double? glassSizeMl,
    bool? onboardingCompleted,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    weightUnit: weightUnit ?? this.weightUnit,
    lengthUnit: lengthUnit ?? this.lengthUnit,
    waterUnit: waterUnit ?? this.waterUnit,
    defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
    glassSizeMl: glassSizeMl ?? this.glassSizeMl,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
  );
}

class SettingsRepository {
  SettingsRepository(this._db);
  final AppDatabase _db;

  Future<AppSettings> load() async {
    final rows = await _db.db.query('app_settings', where: 'id = 1');
    return rows.isEmpty ? const AppSettings() : AppSettings.fromMap(rows.first);
  }

  Future<void> save(AppSettings settings) => _db.db.update('app_settings', settings.toMap(), where: 'id = 1');
}

final settingsRepositoryProvider = Provider((ref) => SettingsRepository(ref.watch(databaseProvider)));

/// Loaded before `runApp` so the first frame already has the right theme.
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> update(AppSettings Function(AppSettings current) change) async {
    final next = change(state);
    await ref.read(settingsRepositoryProvider).save(next);
    state = next;
  }

  /// Re-reads from the database (after a restore or reset).
  Future<void> reload() async {
    state = await ref.read(settingsRepositoryProvider).load();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
