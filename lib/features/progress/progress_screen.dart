import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../exercises/exercise.dart';
import '../nutrition/nutrition_models.dart';
import '../nutrition/nutrition_providers.dart';
import '../profile/user_profile.dart';
import '../settings/app_settings.dart';
import '../workout/workout_calculations.dart';
import '../workout/workout_providers.dart';
import 'body_repository.dart';
import 'charts.dart';
import 'progress_stats.dart';
import 'weight_entry_sheet.dart';

/// Completed workouts in the last 7 and 30 days.
final workoutCountsProvider = FutureProvider.autoDispose<({int last7, int last30})>((ref) async {
  ref.watch(workoutRevisionProvider);
  final today = ref.watch(todayProvider);
  final repo = ref.watch(sessionRepositoryProvider);
  final to = dateKey(today);
  return (
    last7: await repo.completedCount(dateKey(addDays(today, -6)), to),
    last30: await repo.completedCount(dateKey(addDays(today, -29)), to),
  );
});

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => showWeightEntrySheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Record weight'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [Text('Progress', style: Theme.of(context).textTheme.headlineSmall)]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: PillTabs(
                labels: const ['Overview', 'Weight', 'Strength'],
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: switch (_tab) {
                0 => const _OverviewTab(),
                1 => const WeightTab(),
                _ => const _StrengthTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  int? _period = 30;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final unit = ref.watch(settingsProvider).weightUnit;
    final lengthUnit = ref.watch(settingsProvider).lengthUnit;
    final profile = ref.watch(profileProvider);
    final weights = ref.watch(weightLogsProvider).value ?? const <WeightLog>[];
    final stats = weightStats(weights, today: today, periodDays: _period);
    final daily = ref.watch(recentDailyTotalsProvider(7)).value ?? const <String, Nutrients>{};
    final counts = ref.watch(workoutCountsProvider).value;
    final plan = ref.watch(activePlanProvider).value;
    final measurements = latestMeasurements(ref.watch(measurementsProvider).value ?? const []);
    final days = [for (var i = 6; i >= 0; i--) dateKey(addDays(today, -i))];
    final logged = daily.values.toList();
    final avg = logged.isEmpty ? null : Nutrients.sum(logged).scale(1 / logged.length);
    final periodLabel = PeriodChips.options.firstWhere((o) => o.$1 == _period).$2;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Body weight', style: t.titleMedium),
              const SizedBox(height: 10),
              if (stats.latest == null)
                EmptyState(
                  icon: Icons.monitor_weight_outlined,
                  title: 'No weigh-ins yet',
                  message: 'Record your weight to see the trend here.',
                  action: 'Record weight',
                  onAction: () => showWeightEntrySheet(context),
                  compact: true,
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatWeight(stats.latest!.weightKg, unit), style: t.headlineSmall),
                          Text(
                            'Latest · ${relativeDayLabel(parseDateKey(stats.latest!.date), today)}',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            stats.periodChangeKg == null ? '—' : formatWeightChange(stats.periodChangeKg!, unit),
                            style: t.headlineSmall?.copyWith(color: p.accentText),
                          ),
                          Text(
                            stats.periodChangeKg == null ? 'Need 2+ entries' : 'Change · $periodLabel',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (stats.weeklyAverageKg != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '7-day average: ${formatWeight(stats.weeklyAverageKg!, unit)} '
                    '(${stats.weeklyAverageCount} ${stats.weeklyAverageCount == 1 ? 'entry' : 'entries'})',
                    style: t.bodySmall,
                  ),
                ],
                if (profile.targetWeightKg != null)
                  Text('Target: ${formatWeight(profile.targetWeightKg!, unit)}', style: t.bodySmall),
                const SizedBox(height: 12),
                PeriodChips(selected: _period, onChanged: (v) => setState(() => _period = v)),
                const SizedBox(height: 12),
                if (stats.entriesInPeriod.isEmpty)
                  Text('No entries in this period.', style: t.bodySmall)
                else
                  DatedLineChart(
                    points: [
                      for (final w in stats.entriesInPeriod) DatedValue(w.date, weightForDisplay(w.weightKg, unit)),
                    ],
                    unit: unit.label,
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => context.go('/progress/weight'), child: const Text('View history')),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Calories · last 7 days', style: t.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${daily.length} of 7 days logged${profile.calorieTarget != null ? ' · dashed line = target' : ''}',
                style: t.bodySmall,
              ),
              const SizedBox(height: 12),
              DailyBarChart(
                days: days,
                values: {for (final e in daily.entries) e.key: e.value.calories},
                target: profile.calorieTarget,
              ),
              if (avg != null) ...[
                const SizedBox(height: 12),
                Text('Average on logged days', style: t.labelMedium),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _avgCell(context, formatThousands(avg.calories), 'kcal', p.text),
                    _avgCell(context, formatGrams(avg.protein), 'protein', p.protein),
                    _avgCell(context, formatGrams(avg.carbs), 'carbs', p.carbs),
                    _avgCell(context, formatGrams(avg.fat), 'fat', p.fat),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(16),
          onTap: () => context.go('/workout/history'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Workout consistency', style: t.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  _avgCell(context, '${counts?.last7 ?? '–'}', 'last 7 days', p.accentText),
                  _avgCell(context, '${counts?.last30 ?? '–'}', 'last 30 days', p.accentText),
                  _avgCell(context, '${plan?.trainingDays ?? '–'}', 'planned / week', p.text),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Body measurements', style: t.titleMedium)),
                  TextButton(
                    onPressed: () => context.go('/progress/measurements'),
                    child: Text(measurements.isEmpty ? 'Add' : 'View all'),
                  ),
                ],
              ),
              if (measurements.isEmpty)
                Text('Optional: track chest, waist, arms and more.', style: t.bodySmall)
              else
                for (final m in measurements.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(child: Text(m.type, style: t.bodyMedium)),
                        Text(
                          formatLength(m.valueCm, lengthUnit),
                          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Text(formatShortDate(parseDateKey(m.date)), style: t.bodySmall),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avgCell(BuildContext context, String value, String label, Color color) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: t.titleLarge?.copyWith(color: color, fontSize: 18)),
          Text(label, style: t.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Weight chart and full history (also used by the Weight history screen).
class WeightTab extends ConsumerStatefulWidget {
  const WeightTab({super.key});

  @override
  ConsumerState<WeightTab> createState() => _WeightTabState();
}

class _WeightTabState extends ConsumerState<WeightTab> {
  int? _period = 90;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final today = ref.watch(todayProvider);
    final unit = ref.watch(settingsProvider).weightUnit;
    final logs = ref.watch(weightLogsProvider);
    return AsyncView(
      value: logs,
      builder: (logs) {
        if (logs.isEmpty) {
          return EmptyState(
            icon: Icons.monitor_weight_outlined,
            title: 'No weigh-ins yet',
            message: 'One entry per day. Weighing at a similar time each day makes trends clearer.',
            action: 'Record weight',
            onAction: () => showWeightEntrySheet(context),
          );
        }
        final stats = weightStats(logs, today: today, periodDays: _period);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            PeriodChips(selected: _period, onChanged: (v) => setState(() => _period = v)),
            const SizedBox(height: 12),
            AppCard(
              child: stats.entriesInPeriod.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('No entries in this period.', style: t.bodySmall),
                    )
                  : DatedLineChart(
                      points: [
                        for (final w in stats.entriesInPeriod) DatedValue(w.date, weightForDisplay(w.weightKg, unit)),
                      ],
                      unit: unit.label,
                      height: 220,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              [
                'Latest ${formatWeight(stats.latest!.weightKg, unit)}',
                if (stats.weeklyAverageKg != null) '7-day average ${formatWeight(stats.weeklyAverageKg!, unit)}',
                if (stats.periodChangeKg != null) 'change ${formatWeightChange(stats.periodChangeKg!, unit)}',
              ].join(' · '),
              style: t.bodySmall,
            ),
            const SectionTitle('History'),
            for (var i = logs.length - 1; i >= 0; i--)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AppCard(
                  onTap: () => showWeightEntrySheet(context, existing: logs[i]),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatMediumDate(parseDateKey(logs[i].date)), style: t.bodyMedium),
                            if (logs[i].notes.isNotEmpty) Text(logs[i].notes, style: t.bodySmall),
                          ],
                        ),
                      ),
                      Text(formatWeight(logs[i].weightKg, unit), style: t.titleSmall),
                      if (i > 0) ...[
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 64,
                          child: Text(
                            formatWeightChange(logs[i].weightKg - logs[i - 1].weightKg, unit),
                            textAlign: TextAlign.end,
                            style: t.bodySmall?.copyWith(color: p.textSecondary),
                          ),
                        ),
                      ] else
                        const SizedBox(width: 74),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _StrengthMetric { topWeight, e1rm, volume, reps, time, distance }

class _StrengthTab extends ConsumerStatefulWidget {
  const _StrengthTab();

  @override
  ConsumerState<_StrengthTab> createState() => _StrengthTabState();
}

class _StrengthTabState extends ConsumerState<_StrengthTab> {
  int? _exerciseId;
  _StrengthMetric? _metric;

  List<_StrengthMetric> _metricsFor(ExerciseType type) => switch (type) {
    ExerciseType.weightReps => const [_StrengthMetric.topWeight, _StrengthMetric.e1rm, _StrengthMetric.volume],
    ExerciseType.bodyweightReps => const [_StrengthMetric.reps, _StrengthMetric.topWeight],
    ExerciseType.time => const [_StrengthMetric.time],
    ExerciseType.distance => const [_StrengthMetric.distance, _StrengthMetric.time],
  };

  String _metricLabel(_StrengthMetric m) => switch (m) {
    _StrengthMetric.topWeight => 'Heaviest set',
    _StrengthMetric.e1rm => 'Est. 1RM',
    _StrengthMetric.volume => 'Volume',
    _StrengthMetric.reps => 'Most reps',
    _StrengthMetric.time => 'Time',
    _StrengthMetric.distance => 'Distance',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final unit = ref.watch(settingsProvider).weightUnit;
    final exercises = ref.watch(exercisesWithHistoryProvider);
    return AsyncView(
      value: exercises,
      builder: (exercises) {
        if (exercises.isEmpty) {
          return const EmptyState(
            icon: Icons.show_chart,
            title: 'No strength data yet',
            message: 'Finish a workout with completed sets and your progress per exercise appears here.',
          );
        }
        final exercise = exercises.firstWhere((e) => e.id == _exerciseId, orElse: () => exercises.first);
        final metrics = _metricsFor(exercise.type);
        final metric = metrics.contains(_metric) ? _metric! : metrics.first;
        final history = ref.watch(exerciseHistoryProvider(exercise.id)).value ?? const <ExerciseSessionStats>[];
        double? valueOf(ExerciseSessionStats s) => switch (metric) {
          _StrengthMetric.topWeight => s.topWeightKg == null ? null : weightForDisplay(s.topWeightKg!, unit),
          _StrengthMetric.e1rm => s.bestE1rm == null ? null : weightForDisplay(s.bestE1rm!, unit),
          _StrengthMetric.volume => s.volumeKg > 0 ? weightForDisplay(s.volumeKg, unit) : null,
          _StrengthMetric.reps => s.mostReps?.toDouble(),
          _StrengthMetric.time => s.longestSeconds?.toDouble(),
          _StrengthMetric.distance => s.longestDistanceM == null ? null : s.longestDistanceM! / 1000,
        };
        final metricUnit = switch (metric) {
          _StrengthMetric.reps => 'reps',
          _StrengthMetric.time => 's',
          _StrengthMetric.distance => 'km',
          _ => unit.label,
        };
        final points = [
          for (final s in history)
            if (valueOf(s) != null) DatedValue(s.date, valueOf(s)!),
        ];
        final records = ExerciseRecords.from(history);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            LabeledDropdown<int>(
              label: 'Exercise',
              value: exercise.id,
              items: exercises.map((e) => e.id).toList(),
              itemLabel: (id) => exercises.firstWhere((e) => e.id == id).name,
              onChanged: (v) => setState(() => _exerciseId = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final m in metrics)
                  ChoiceChip(
                    label: Text(_metricLabel(m)),
                    selected: m == metric,
                    showCheckmark: false,
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, color: m == metric ? p.onAccent : p.text),
                    onSelected: (_) => setState(() => _metric = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              child: points.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('No data for this measure yet.', style: t.bodySmall),
                    )
                  : DatedLineChart(points: points, unit: metricUnit, height: 210),
            ),
            if (metric == _StrengthMetric.e1rm)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Estimated 1RM = weight × (1 + reps ÷ 30) (Epley), from sets of 1–12 reps. It is an estimate, not a tested maximum.',
                  style: t.bodySmall,
                ),
              ),
            if (metric == _StrengthMetric.volume)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Volume = weight × reps over completed sets with external load.', style: t.bodySmall),
              ),
            const SectionTitle('Personal bests'),
            AppCard(
              child: Column(
                children: [
                  if (records.heaviest != null)
                    _recordRow(
                      context,
                      'Heaviest set',
                      '${formatWeight(records.heaviest!.topWeightKg!, unit)} × ${records.heaviest!.topWeightReps ?? '—'}',
                      records.heaviest!.date,
                    ),
                  if (records.bestE1rm != null)
                    _recordRow(
                      context,
                      'Best estimated 1RM',
                      formatWeight(records.bestE1rm!.bestE1rm!, unit),
                      records.bestE1rm!.date,
                    ),
                  if (records.mostReps != null && exercise.type.usesReps)
                    _recordRow(context, 'Most reps in a set', '${records.mostReps!.mostReps}', records.mostReps!.date),
                  if (records.bestVolume != null)
                    _recordRow(
                      context,
                      'Most volume in a session',
                      formatWeight(records.bestVolume!.volumeKg, unit, decimals: 0),
                      records.bestVolume!.date,
                    ),
                  if (records.longestSeconds != null)
                    _recordRow(
                      context,
                      'Longest time',
                      formatDurationShort(Duration(seconds: records.longestSeconds!.longestSeconds!)),
                      records.longestSeconds!.date,
                    ),
                  if (records.longestDistanceM != null)
                    _recordRow(
                      context,
                      'Longest distance',
                      '${formatNumber(records.longestDistanceM!.longestDistanceM! / 1000, decimals: 2)} km',
                      records.longestDistanceM!.date,
                    ),
                ],
              ),
            ),
            const SectionTitle('Sessions'),
            for (final s in history.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AppCard(
                  onTap: () => context.go('/workout/history/${s.sessionId}'),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      Expanded(child: Text(formatMediumDate(parseDateKey(s.date)), style: t.bodyMedium)),
                      Text(
                        [
                          '${s.completedSets} sets',
                          if (s.topWeightKg != null)
                            'top ${formatWeight(s.topWeightKg!, unit)} × ${s.topWeightReps ?? '—'}',
                          if (s.topWeightKg == null && s.mostReps != null) 'best ${s.mostReps} reps',
                          if (s.longestSeconds != null) formatDurationShort(Duration(seconds: s.longestSeconds!)),
                        ].join(' · '),
                        style: t.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _recordRow(BuildContext context, String label, String value, String date) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.bodyMedium)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(formatShortDate(parseDateKey(date)), style: t.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
