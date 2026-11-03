import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/feedback.dart';
import 'models.dart';
import 'session_controller.dart';
import 'workout_providers.dart';

/// Starts [day] as a live session, or offers to resume the one already in
/// progress so two sessions never run at once.
Future<void> startWorkoutFromDay(BuildContext context, WidgetRef ref, PlanDay day) async {
  if (!await _resumeIfActive(context, ref)) return;
  if (day.exercises.isEmpty) {
    if (context.mounted) showSnack(context, 'Add exercises to ${weekdayName(day.weekday)} first.');
    return;
  }
  final today = ref.read(todayProvider);
  await ref.read(sessionControllerProvider.notifier).startFromPlanDay(day, dateKey(today));
  if (context.mounted) context.go('/workout/session');
}

/// Starts an empty session to fill in exercise by exercise.
Future<void> startQuickWorkout(BuildContext context, WidgetRef ref) async {
  if (!await _resumeIfActive(context, ref)) return;
  final today = ref.read(todayProvider);
  await ref.read(sessionControllerProvider.notifier).startEmpty(dateKey(today));
  if (context.mounted) context.go('/workout/session');
}

/// Returns true when the caller may start a new session.
Future<bool> _resumeIfActive(BuildContext context, WidgetRef ref) async {
  final active = await ref.read(sessionRepositoryProvider).activeSession();
  if (active == null) return true;
  if (!context.mounted) return false;
  final resume = await showConfirmDialog(
    context,
    title: 'Workout in progress',
    message:
        'You have an unfinished workout ("${active.name}"). Resume it? '
        'To start a different one, finish or discard it first.',
    confirm: 'Resume',
  );
  if (resume && context.mounted) context.go('/workout/session');
  return false;
}
