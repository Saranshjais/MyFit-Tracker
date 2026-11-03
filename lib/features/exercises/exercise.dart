import 'package:flutter/foundation.dart';

import 'muscles.dart';

/// How a set of this exercise is measured.
enum ExerciseType {
  weightReps('weight_reps', 'Weight × reps'),
  bodyweightReps('bodyweight_reps', 'Bodyweight reps (optional added weight)'),
  time('time', 'Timed hold'),
  distance('distance', 'Distance and time');

  const ExerciseType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static ExerciseType fromDb(Object? v) =>
      ExerciseType.values.firstWhere((t) => t.dbValue == v, orElse: () => ExerciseType.weightReps);

  bool get usesReps => this == weightReps || this == bodyweightReps;
}

const muscleGroups = ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core', 'Cardio', 'Full Body'];
const equipmentTypes = [
  'Barbell',
  'Dumbbell',
  'Cable',
  'Machine',
  'Bodyweight',
  'Kettlebell',
  'EZ Bar',
  'Resistance Band',
  'Other',
];

@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.equipment,
    this.secondaryMuscles = const [],
    this.targetMuscles = const [],
    this.assistMuscles = const [],
    this.type = ExerciseType.weightReps,
    this.description = '',
    this.instructions = const [],
    this.isCustom = false,
    this.isArchived = false,
  });

  final int id;
  final String name;

  /// Primary muscle group, one of [muscleGroups] (or a custom value).
  final String muscle;
  final String equipment;

  /// Other muscle groups (body-part names) the exercise works.
  final List<String> secondaryMuscles;

  /// Muscles the exercise mainly builds.
  final List<Muscle> targetMuscles;

  /// Muscles that help and get some training too.
  final List<Muscle> assistMuscles;
  final ExerciseType type;
  final String description;
  final List<String> instructions;
  final bool isCustom;
  final bool isArchived;

  factory Exercise.fromMap(Map<String, Object?> m, {String prefix = ''}) {
    String s(String key) => (m['$prefix$key'] as String?) ?? '';
    final secondary = s('secondary_muscles');
    final instructions = s('instructions');
    return Exercise(
      id: m['${prefix}id'] as int,
      name: s('name'),
      muscle: s('muscle'),
      equipment: s('equipment'),
      secondaryMuscles: secondary.isEmpty ? const [] : secondary.split(','),
      targetMuscles: Muscle.parse(m['${prefix}target_muscles'] as String?),
      assistMuscles: Muscle.parse(m['${prefix}assist_muscles'] as String?),
      type: ExerciseType.fromDb(m['${prefix}exercise_type']),
      description: s('description'),
      instructions: instructions.isEmpty ? const [] : instructions.split('\n'),
      isCustom: m['${prefix}is_custom'] == 1,
      isArchived: m['${prefix}is_archived'] == 1,
    );
  }

  Map<String, Object?> toMap() => {
    'name': name.trim(),
    'muscle': muscle,
    'equipment': equipment,
    'secondary_muscles': secondaryMuscles.join(','),
    'target_muscles': Muscle.encode(targetMuscles),
    'assist_muscles': Muscle.encode(assistMuscles),
    'exercise_type': type.dbValue,
    'description': description.trim(),
    'instructions': instructions.where((s) => s.trim().isNotEmpty).map((s) => s.trim()).join('\n'),
    'is_custom': isCustom ? 1 : 0,
    'is_archived': isArchived ? 1 : 0,
  };

  /// All muscles worked, main ones first.
  List<Muscle> get allMuscles => [...targetMuscles, ...assistMuscles.where((m) => !targetMuscles.contains(m))];

  /// Body parts of the main muscles, e.g. "Chest" or "Legs".
  List<BodyPart> get targetParts => targetMuscles.map((m) => m.part).toSet().toList();

  /// Body-part names of assisting muscles outside the main group. Stored in
  /// `secondary_muscles` so older code and backups stay meaningful.
  static List<String> secondaryGroupsFor(String group, List<Muscle> assists) =>
      assists.map((m) => m.part.label).where((p) => p != group).toSet().toList();

  /// Column list for joins: `e.id AS ex_id, …`.
  static String selectColumns(String alias, String prefix) => [
    'id',
    'name',
    'muscle',
    'equipment',
    'secondary_muscles',
    'target_muscles',
    'assist_muscles',
    'exercise_type',
    'description',
    'instructions',
    'is_custom',
    'is_archived',
  ].map((c) => '$alias.$c AS $prefix$c').join(', ');
}
