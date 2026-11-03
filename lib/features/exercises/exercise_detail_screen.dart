import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/feedback.dart';
import '../settings/app_settings.dart';
import '../workout/screens/add_to_plan_sheet.dart';
import '../workout/workout_calculations.dart';
import '../workout/workout_providers.dart';
import 'exercise.dart';
import 'exercise_repository.dart';
import 'body_map.dart';
import 'exercise_thumb.dart';
import 'muscles.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});
  final int exerciseId;

  Future<void> _delete(BuildContext context, WidgetRef ref, Exercise e) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Remove "${e.name}"?',
      message:
          'If it is used in a plan or in past workouts it will be hidden from the library but kept in your history.',
      confirm: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    final archived = await ref.read(exerciseRepositoryProvider).deleteOrArchive(e.id);
    ref.read(workoutRevisionProvider.notifier).bump();
    if (!context.mounted) return;
    showSnack(context, archived ? 'Hidden from the library. Your history is kept.' : 'Exercise removed.');
    context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseProvider(exerciseId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise'),
        actions: [
          if (exercise.value != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') context.push('/workout/exercise/$exerciseId/edit');
                if (v == 'delete') _delete(context, ref, exercise.value!);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Remove from library')),
              ],
            ),
        ],
      ),
      body: AsyncView(
        value: exercise,
        builder: (e) {
          if (e == null) return const EmptyState(icon: Icons.help_outline, title: 'Exercise not found');
          final t = Theme.of(context).textTheme;
          return ListView(
            padding: pagePadding,
            children: [
              ExerciseHero(exercise: e, height: 220),
              if (e.targetMuscles.isNotEmpty) ...[const SizedBox(height: 8), const BodyMapLegend()],
              const SizedBox(height: 16),
              Text(e.name, style: t.headlineSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Badge2(e.muscle, color: context.palette.accentText),
                  Badge2(e.equipment),
                  Badge2(e.type.label),
                  if (e.isCustom) const Badge2('Custom'),
                ],
              ),
              if (e.description.isNotEmpty) ...[const SizedBox(height: 14), Text(e.description, style: t.bodyMedium)],
              _MusclesSection(exercise: e),
              if (e.instructions.isNotEmpty) ...[
                const SectionTitle('How to do it'),
                for (var i = 0; i < e.instructions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: context.palette.accentSoft,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.palette.accentText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(e.instructions[i], style: t.bodyMedium?.copyWith(height: 1.4))),
                      ],
                    ),
                  ),
                Text(
                  'General guidance only. Use a weight you can control and stop if something hurts.',
                  style: t.bodySmall,
                ),
              ],
              _RecordsSection(exercise: e),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => showAddToPlanSheet(context, ref, e),
                icon: const Icon(Icons.add),
                label: const Text('Add to workout'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Body part and the specific muscles the exercise builds, with what each
/// muscle does, plus other exercises for the same main muscle.
class _MusclesSection extends ConsumerWidget {
  const _MusclesSection({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = exercise;
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    if (e.targetMuscles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          e.isCustom
              ? 'No specific muscles set. Edit the exercise to choose which muscles it works.'
              : 'Works: ${[e.muscle, ...e.secondaryMuscles].join(', ')}',
          style: t.bodySmall,
        ),
      );
    }
    final all = ref.watch(exercisesProvider).value ?? const <Exercise>[];
    final main = e.targetMuscles.first;
    final similar = all.where((x) => x.id != e.id && x.targetMuscles.contains(main)).take(6).toList();

    Widget muscleRow(Muscle m, {required bool primary}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: primary ? p.accent : p.accent.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: m.label, style: t.titleSmall),
                      TextSpan(text: '  ·  ${m.part.label}', style: t.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                Text(m.anatomy, style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                const SizedBox(height: 2),
                Text(m.role, style: t.bodySmall?.copyWith(color: p.text)),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Muscles worked'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Body part', style: t.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final part in e.targetParts) Badge2(part.label, color: p.accentText),
                  for (final part in e.assistMuscles.map((m) => m.part).toSet().difference(e.targetParts.toSet()))
                    Badge2(part.label),
                ],
              ),
              const SizedBox(height: 14),
              Text('Main muscles: grows these the most', style: t.labelMedium),
              for (final m in e.targetMuscles) muscleRow(m, primary: true),
              if (e.assistMuscles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Also works: helping muscles that get some training', style: t.labelMedium),
                for (final m in e.assistMuscles) muscleRow(m, primary: false),
              ],
            ],
          ),
        ),
        if (similar.isNotEmpty) ...[
          SectionTitle('More for your ${main.label.toLowerCase()}'),
          for (final x in similar)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(10),
                onTap: () => context.push('/workout/exercise/${x.id}'),
                child: Row(
                  children: [
                    ExerciseThumb(exercise: x, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(x.name, style: t.titleSmall),
                          Text(x.equipment, style: t.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: p.textMuted),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _RecordsSection extends ConsumerWidget {
  const _RecordsSection({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(exerciseHistoryProvider(exercise.id)).value ?? const [];
    if (history.isEmpty) return const SizedBox.shrink();
    final unit = ref.watch(settingsProvider).weightUnit;
    final r = ExerciseRecords.from(history);
    final last = history.last;
    final t = Theme.of(context).textTheme;
    final rows = <(String, String)>[
      ('Sessions logged', '${history.length}'),
      ('Last done', formatMediumDate(parseDateKey(last.date))),
      if (r.heaviest != null)
        ('Heaviest set', '${formatWeight(r.heaviest!.topWeightKg!, unit)} × ${r.heaviest!.topWeightReps ?? '—'}'),
      if (r.bestE1rm != null) ('Best estimated 1RM', '${formatWeight(r.bestE1rm!.bestE1rm!, unit)} (estimate)'),
      if (r.mostReps != null && exercise.type.usesReps) ('Most reps in a set', '${r.mostReps!.mostReps}'),
      if (r.longestSeconds != null)
        ('Longest time', formatDurationShort(Duration(seconds: r.longestSeconds!.longestSeconds!))),
      if (r.longestDistanceM != null)
        ('Longest distance', '${formatNumber(r.longestDistanceM!.longestDistanceM! / 1000, decimals: 2)} km'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Your history'),
        AppCard(
          child: Column(
            children: [
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(label, style: t.bodySmall)),
                      Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
