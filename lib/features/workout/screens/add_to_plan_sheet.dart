import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/feedback.dart';
import '../../exercises/exercise.dart';
import '../../settings/app_settings.dart';
import '../session_controller.dart';
import '../workout_providers.dart';

/// Default targets for a newly planned exercise, by how it is logged.
({int sets, int? minReps, int? maxReps}) defaultTargets(ExerciseType type) => switch (type) {
  ExerciseType.weightReps => (sets: 3, minReps: 8, maxReps: 12),
  ExerciseType.bodyweightReps => (sets: 3, minReps: 8, maxReps: 15),
  ExerciseType.time => (sets: 3, minReps: 30, maxReps: 60),
  ExerciseType.distance => (sets: 1, minReps: null, maxReps: null),
};

/// Lets the user add [exercise] to the current workout or a day of the plan.
Future<void> showAddToPlanSheet(BuildContext context, WidgetRef ref, Exercise exercise) async {
  final plan = await ref.read(activePlanProvider.future);
  final active = ref.read(sessionControllerProvider).value;
  if (!context.mounted) return;
  if (plan == null && active == null) {
    showSnack(context, 'Create a workout plan first (Workout › Manage plans).');
    return;
  }
  final choice = await showChoiceSheet<int>(
    context,
    title: 'Add ${exercise.name} to…',
    options: [
      if (active != null) (value: -1, label: 'Current workout', subtitle: active.name, icon: Icons.timer_outlined),
      if (plan != null)
        for (final d in plan.days)
          (
            value: d.id,
            label: weekdayName(d.weekday),
            subtitle: d.isRestDay
                ? 'Rest day (becomes a training day)'
                : '${d.title} · ${d.exercises.length} exercises',
            icon: Icons.calendar_today_outlined,
          ),
    ],
  );
  if (choice == null || !context.mounted) return;
  final rest = ref.read(settingsProvider).defaultRestSeconds;
  if (choice == -1) {
    await ref.read(sessionControllerProvider.notifier).addExercise(exercise);
    if (context.mounted) showSnack(context, 'Added to your current workout.');
    return;
  }
  final targets = defaultTargets(exercise.type);
  await runGuarded(context, () async {
    await ref
        .read(planRepositoryProvider)
        .addExercise(
          choice,
          exercise.id,
          sets: targets.sets,
          minReps: targets.minReps,
          maxReps: targets.maxReps,
          restSeconds: rest,
        );
    ref.read(workoutRevisionProvider.notifier).bump();
  }, success: 'Added to ${weekdayName(plan!.days.firstWhere((d) => d.id == choice).weekday)}.');
}
