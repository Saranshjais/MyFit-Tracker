import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/feedback.dart';
import '../../exercises/exercise.dart';
import '../../exercises/exercise_thumb.dart';
import '../../settings/app_settings.dart';
import '../models.dart';
import '../workout_calculations.dart';
import '../workout_providers.dart';

class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({super.key, required this.sessionId, this.justFinished = false});
  final int sessionId;
  final bool justFinished;

  Future<void> _menu(BuildContext context, WidgetRef ref, WorkoutSession s, String action) async {
    final repo = ref.read(sessionRepositoryProvider);
    void bump() => ref.read(workoutRevisionProvider.notifier).bump();
    switch (action) {
      case 'duration':
        final minutes = await showNumberInputDialog(
          context,
          title: 'Workout duration',
          label: 'Minutes',
          initial: (s.durationSeconds / 60).roundToDouble(),
          decimal: false,
          max: 600,
          helper: 'Fix the time if you left the session open after training.',
        );
        if (minutes == null) return;
        await repo.updateDuration(s.id, (minutes * 60).round());
        bump();
      case 'notes':
        final notes = await showTextInputDialog(
          context,
          title: 'Notes',
          initial: s.notes,
          label: 'How did it go?',
          maxLength: 300,
        );
        if (notes == null) return;
        await repo.updateNotes(s.id, notes);
        bump();
      case 'delete':
        final ok = await showConfirmDialog(
          context,
          title: 'Delete this workout?',
          message: 'All sets logged in "${s.name}" on ${formatMediumDate(parseDateKey(s.date))} will be deleted.',
          confirm: 'Delete',
          destructive: true,
        );
        if (!ok) return;
        await repo.delete(s.id);
        bump();
        if (context.mounted) context.go('/workout/history');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionDetailProvider(sessionId));
    final session = async.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(justFinished ? 'Workout complete' : 'Workout'),
        automaticallyImplyLeading: !justFinished,
        actions: [
          if (session != null && !session.isActive)
            PopupMenuButton<String>(
              onSelected: (a) => _menu(context, ref, session, a),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'duration', child: Text('Edit duration')),
                PopupMenuItem(value: 'notes', child: Text('Edit notes')),
                PopupMenuItem(value: 'delete', child: Text('Delete workout')),
              ],
            ),
        ],
      ),
      body: AsyncView(
        value: async,
        builder: (s) => s == null
            ? const EmptyState(
                icon: Icons.help_outline,
                title: 'Workout not found',
                message: 'It may have been deleted.',
              )
            : _SummaryBody(session: s, justFinished: justFinished),
      ),
    );
  }
}

class _SummaryBody extends ConsumerWidget {
  const _SummaryBody({required this.session, required this.justFinished});
  final WorkoutSession session;
  final bool justFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final unit = ref.watch(settingsProvider).weightUnit;
    final summary = summarizeSession(session);
    final records = ref.watch(sessionRecordsProvider(session.id)).value ?? const <PersonalRecord>[];
    final today = ref.watch(todayProvider);

    return ListView(
      padding: pagePadding,
      children: [
        if (justFinished) ...[
          Row(
            children: [
              Icon(Icons.check_circle, color: p.accentText, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text('Saved. Nice work.', style: t.titleLarge)),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text(session.name, style: t.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '${relativeDayLabel(parseDateKey(session.date), today)} · ${formatDurationShort(Duration(seconds: session.durationSeconds))}',
          style: t.bodySmall,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Exercises',
                value: '${summary.completedExercises}',
                caption: 'of ${summary.totalExercises}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(label: 'Sets', value: '${summary.completedSets}', caption: 'completed'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        MetricTile(
          label: 'Lifted volume',
          value: summary.volumeSets == 0 ? '—' : formatWeight(summary.volumeKg, unit, decimals: 0),
          caption: [
            'Weight × reps from ${summary.volumeSets} sets with external load.',
            if (summary.excludedSets > 0) '${summary.excludedSets} bodyweight, timed or distance sets are not counted.',
          ].join(' '),
        ),
        if (records.isNotEmpty) ...[
          const SectionTitle('New personal records'),
          AppCard(
            child: Column(
              children: [
                for (final group in _byExercise(records))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.emoji_events, color: p.fat, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(group.first.exercise.name, style: t.titleSmall),
                              Text(
                                group.map((r) => '${_recordLabel(r.kind)} ${_recordValue(r, unit)}').join(' · '),
                                style: t.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (records.any((r) => r.kind == RecordKind.bestEstimatedOneRepMax))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Estimated 1RM uses the Epley formula: weight × (1 + reps ÷ 30). It is an estimate, not a tested lift.',
                      style: t.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SectionTitle('Exercises'),
        for (final e in session.exercises) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExerciseThumb(exercise: e.exercise, size: 38),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.exercise.name, style: t.titleSmall)),
                    if (e.status == SessionExerciseStatus.skipped) Badge2('Skipped', color: p.textMuted),
                  ],
                ),
                if (e.sets.isNotEmpty) const SizedBox(height: 8),
                for (final s in e.sets.where((s) => s.isCompleted))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(width: 56, child: Text('Set ${s.setNumber}', style: t.bodySmall)),
                        Expanded(child: Text(_setText(s, e.exercise.type, unit), style: t.bodyMedium)),
                      ],
                    ),
                  ),
                if (e.sets.isEmpty && e.status != SessionExerciseStatus.skipped)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('No set details recorded.', style: t.bodySmall),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (session.notes.isNotEmpty) ...[const SectionTitle('Notes'), Text(session.notes, style: t.bodyMedium)],
        if (justFinished) ...[
          const SizedBox(height: 20),
          FilledButton(onPressed: () => context.go('/home'), child: const Text('Done')),
        ],
      ],
    );
  }
}

/// Records grouped per exercise, in session order.
List<List<PersonalRecord>> _byExercise(List<PersonalRecord> records) {
  final groups = <int, List<PersonalRecord>>{};
  for (final r in records) {
    groups.putIfAbsent(r.exercise.id, () => []).add(r);
  }
  return groups.values.toList();
}

String _recordLabel(RecordKind kind) => switch (kind) {
  RecordKind.heaviestWeight => 'Heaviest',
  RecordKind.bestEstimatedOneRepMax => 'Est. 1RM',
  RecordKind.mostReps => 'Most reps',
  RecordKind.longestHold => 'Longest',
  RecordKind.longestDistance => 'Farthest',
  RecordKind.bestVolume => 'Volume',
};

String _recordValue(PersonalRecord r, WeightUnit unit) => switch (r.kind) {
  RecordKind.heaviestWeight ||
  RecordKind.bestEstimatedOneRepMax ||
  RecordKind.bestVolume => formatWeight(r.value, unit),
  RecordKind.mostReps => '${r.value.round()} reps',
  RecordKind.longestHold => formatDurationShort(Duration(seconds: r.value.round())),
  RecordKind.longestDistance => '${formatNumber(r.value / 1000, decimals: 2)} km',
};

String _setText(SetLog s, ExerciseType type, WeightUnit unit) {
  switch (type) {
    case ExerciseType.weightReps:
      return '${formatWeight(s.weightKg ?? 0, unit)} × ${s.reps ?? 0}';
    case ExerciseType.bodyweightReps:
      final w = s.weightKg ?? 0;
      return w > 0 ? 'Bodyweight + ${formatWeight(w, unit)} × ${s.reps ?? 0}' : '${s.reps ?? 0} reps (bodyweight)';
    case ExerciseType.time:
      return formatDurationShort(Duration(seconds: s.durationSeconds ?? 0));
    case ExerciseType.distance:
      final parts = [
        if (s.distanceMeters != null) '${formatNumber(s.distanceMeters! / 1000, decimals: 2)} km',
        if (s.durationSeconds != null) formatDurationShort(Duration(seconds: s.durationSeconds!)),
      ];
      return parts.join(' in ');
  }
}
