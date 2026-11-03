import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/core_providers.dart';
import '../../core/utils/dates.dart';

enum Sex {
  male('Male'),
  female('Female');

  const Sex(this.label);
  final String label;
}

enum ActivityLevel {
  sedentary('Sedentary', 'Desk job, little exercise', 1.2),
  light('Lightly active', 'Light exercise 1–3 days a week', 1.375),
  moderate('Moderately active', 'Exercise 3–5 days a week', 1.55),
  active('Very active', 'Hard exercise 6–7 days a week', 1.725),
  veryActive('Extremely active', 'Physical job plus training', 1.9);

  const ActivityLevel(this.label, this.description, this.multiplier);
  final String label;
  final String description;

  /// Standard activity multiplier applied to BMR. An estimate, not a measurement.
  final double multiplier;
}

enum FitnessGoal {
  muscleGain('Gain muscle (bulk)'),
  leanMuscleGain('Lean muscle gain'),
  fatLoss('Fat loss'),
  recomposition('Body recomposition'),
  strength('Strength'),
  generalFitness('General fitness');

  const FitnessGoal(this.label);
  final String label;
}

enum DietPreference {
  vegetarian('Vegetarian'),
  eggetarian('Eggetarian'),
  vegan('Vegan'),
  nonVegetarian('Non-vegetarian');

  const DietPreference(this.label);
  final String label;
}

enum TrainingExperience {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const TrainingExperience(this.label);
  final String label;
}

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

@immutable
class UserProfile {
  const UserProfile({
    this.name = '',
    this.age,
    this.sex,
    this.heightCm,
    this.targetWeightKg,
    this.dietPreference,
    this.experience,
    this.weeklyTrainingDays,
    this.workoutDurationMin,
    this.activityLevel,
    this.goal,
    this.calorieTarget,
    this.proteinTarget,
    this.carbsTarget,
    this.fatTarget,
    this.waterTargetMl,
    this.targetsManual = false,
  });

  final String name;
  final int? age;
  final Sex? sex;
  final double? heightCm;
  final double? targetWeightKg;
  final DietPreference? dietPreference;
  final TrainingExperience? experience;
  final int? weeklyTrainingDays;
  final int? workoutDurationMin;
  final ActivityLevel? activityLevel;
  final FitnessGoal? goal;
  final double? calorieTarget;
  final double? proteinTarget;
  final double? carbsTarget;
  final double? fatTarget;
  final double? waterTargetMl;

  /// True when the user typed targets by hand instead of using the estimate.
  final bool targetsManual;

  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  bool get hasNutritionTargets => calorieTarget != null && calorieTarget! > 0;

  factory UserProfile.fromMap(Map<String, Object?> m) => UserProfile(
    name: (m['name'] as String?) ?? '',
    age: m['age'] as int?,
    sex: _enumByName(Sex.values, m['sex']),
    heightCm: (m['height_cm'] as num?)?.toDouble(),
    targetWeightKg: (m['target_weight_kg'] as num?)?.toDouble(),
    dietPreference: _enumByName(DietPreference.values, m['diet_preference']),
    experience: _enumByName(TrainingExperience.values, m['training_experience']),
    weeklyTrainingDays: m['weekly_training_days'] as int?,
    workoutDurationMin: m['workout_duration_min'] as int?,
    activityLevel: _enumByName(ActivityLevel.values, m['activity_level']),
    goal: _enumByName(FitnessGoal.values, m['goal']),
    calorieTarget: (m['calorie_target'] as num?)?.toDouble(),
    proteinTarget: (m['protein_target'] as num?)?.toDouble(),
    carbsTarget: (m['carbs_target'] as num?)?.toDouble(),
    fatTarget: (m['fat_target'] as num?)?.toDouble(),
    waterTargetMl: (m['water_target_ml'] as num?)?.toDouble(),
    targetsManual: m['targets_manual'] == 1,
  );

  Map<String, Object?> toMap() => {
    'name': name.trim(),
    'age': age,
    'sex': sex?.name,
    'height_cm': heightCm,
    'target_weight_kg': targetWeightKg,
    'diet_preference': dietPreference?.name,
    'training_experience': experience?.name,
    'weekly_training_days': weeklyTrainingDays,
    'workout_duration_min': workoutDurationMin,
    'activity_level': activityLevel?.name,
    'goal': goal?.name,
    'calorie_target': calorieTarget,
    'protein_target': proteinTarget,
    'carbs_target': carbsTarget,
    'fat_target': fatTarget,
    'water_target_ml': waterTargetMl,
    'targets_manual': targetsManual ? 1 : 0,
  };
}

class ProfileRepository {
  ProfileRepository(this._db);
  final AppDatabase _db;

  Future<UserProfile> load() async {
    final rows = await _db.db.query('user_profile', where: 'id = 1');
    return rows.isEmpty ? const UserProfile() : UserProfile.fromMap(rows.first);
  }

  Future<void> save(UserProfile profile) =>
      _db.db.update('user_profile', {...profile.toMap(), 'updated_at': timestampNow()}, where: 'id = 1');
}

final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(databaseProvider)));

final initialProfileProvider = Provider<UserProfile>((ref) => const UserProfile());

class ProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() => ref.read(initialProfileProvider);

  Future<void> save(UserProfile profile) async {
    await ref.read(profileRepositoryProvider).save(profile);
    state = profile;
  }

  Future<void> reload() async {
    state = await ref.read(profileRepositoryProvider).load();
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);
