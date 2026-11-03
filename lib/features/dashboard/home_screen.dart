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
import '../../core/widgets/progress_ring.dart';
import '../nutrition/nutrition_models.dart';
import '../nutrition/nutrition_providers.dart';
import '../profile/user_profile.dart';
import '../progress/weight_entry_sheet.dart';
import '../settings/app_settings.dart';
import '../water/water_repository.dart';
import '../water/water_sheet.dart';
import '../workout/models.dart';
import '../workout/session_controller.dart';
import '../workout/workout_actions.dart';
import '../workout/workout_providers.dart';
import 'weekly_activity.dart';

const _messages = [
  'Stay consistent, stronger every day.',
  'Small steps, done often.',
  'Show up, log it, repeat.',
  'Progress over perfection.',
  'One good session at a time.',
  'Consistency beats intensity.',
  'Rest is part of training too.',
];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final profile = ref.watch(profileProvider);
    final t = Theme.of(context).textTheme;
    final dayOfYear = today.difference(DateTime(today.year)).inDays;
    final name = profile.firstName;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: pagePadding,
          children: [
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker(formatLongDate(today)),
                      const SizedBox(height: 6),
                      Text(
                        name.isEmpty ? greetingFor(DateTime.now()) : '${greetingFor(DateTime.now())}, $name',
                        style: t.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(_messages[dayOfYear % _messages.length], style: t.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: 'Profile & goals',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => context.go('/more/profile'),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: context.palette.accentSoft,
                      child: Text(
                        profile.initials,
                        style: TextStyle(color: context.palette.accentText, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _TodayWorkoutCard(),
            const SizedBox(height: 12),
            const _NutritionCard(),
            const SizedBox(height: 12),
            const _QuickActions(),
            const SectionTitle('This week'),
            const _WeeklyActivity(),
            const SizedBox(height: 12),
            const _ConsistencyCard(),
          ],
        ),
      ),
    );
  }
}

class _TodayWorkoutCard extends ConsumerWidget {
  const _TodayWorkoutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final active = ref.watch(sessionControllerProvider).value;
    final day = ref.watch(todayPlanDayProvider);
    final completed = ref.watch(todayCompletedSessionsProvider).value ?? const <WorkoutSession>[];
    final plan = ref.watch(activePlanProvider);

    Widget card({
      required String kicker,
      required String title,
      String? subtitle,
      required Widget action,
      IconData? icon,
    }) => AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(kicker),
                const SizedBox(height: 6),
                Text(title, style: t.titleLarge),
                if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle, style: t.bodySmall)],
                const SizedBox(height: 14),
                action,
              ],
            ),
          ),
          if (icon != null) Icon(icon, size: 52, color: p.accentText.withValues(alpha: 0.85)),
        ],
      ),
    );

    if (active != null) {
      final done = active.exercises.where((e) => e.completedSets > 0).length;
      return card(
        kicker: 'Workout in progress',
        title: active.name,
        subtitle: '$done of ${active.exercises.length} exercises started · since ${formatTime(active.startedAt)}',
        icon: Icons.timer_outlined,
        action: FilledButton.icon(
          onPressed: () => context.go('/workout/session'),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Resume workout'),
        ),
      );
    }
    if (completed.isNotEmpty) {
      final last = completed.last;
      final sets = last.exercises.fold<int>(0, (s, e) => s + e.completedSets);
      return card(
        kicker: "Today's workout",
        title: last.name,
        subtitle: 'Completed · $sets sets · ${formatDurationShort(Duration(seconds: last.durationSeconds))}',
        icon: Icons.check_circle,
        action: OutlinedButton(
          onPressed: () => context.go('/workout/history/${last.id}'),
          child: const Text('View session'),
        ),
      );
    }
    if (day.isLoading || plan.isLoading) return const AppCard(child: LoadingView(padding: EdgeInsets.all(12)));
    final d = day.value;
    if (d == null) {
      return card(
        kicker: "Today's workout",
        title: 'No active plan',
        subtitle: 'Create or choose a weekly plan to see your workout here.',
        icon: Icons.event_note,
        action: FilledButton(onPressed: () => context.go('/workout/plans'), child: const Text('Set up a plan')),
      );
    }
    if (d.isRestDay) {
      return card(
        kicker: "Today's workout",
        title: d.title,
        subtitle: 'Recovery is part of training. Light walking or stretching is fine.',
        icon: Icons.bedtime_outlined,
        action: OutlinedButton(
          onPressed: () => startQuickWorkout(context, ref),
          child: const Text('Log a workout anyway'),
        ),
      );
    }
    if (d.exercises.isEmpty) {
      return card(
        kicker: "Today's workout",
        title: d.title,
        subtitle: 'No exercises planned for today yet.',
        icon: Icons.fitness_center,
        action: FilledButton(onPressed: () => context.go('/workout/day/${d.id}'), child: const Text('Add exercises')),
      );
    }
    return card(
      kicker: "Today's workout",
      title: d.title,
      subtitle: '${d.muscles.take(3).join(' · ')}\n${d.exercises.length} exercises · ~${d.estimatedMinutes} min',
      icon: Icons.fitness_center,
      action: FilledButton.icon(
        onPressed: () => startWorkoutFromDay(context, ref, d),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start workout'),
      ),
    );
  }
}

class _NutritionCard extends ConsumerWidget {
  const _NutritionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final profile = ref.watch(profileProvider);
    final totals = ref.watch(dayTotalsProvider(dateKey(today))).value ?? Nutrients.zero;
    final cal = TargetProgress(totals.calories, profile.calorieTarget);

    return AppCard(
      onTap: () => context.go('/diet'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's nutrition", style: t.titleMedium),
          const SizedBox(height: 14),
          Row(
            children: [
              ProgressRing(
                fraction: cal.fraction,
                over: cal.isOver,
                size: 112,
                stroke: 9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatThousands(totals.calories), style: t.titleLarge?.copyWith(fontSize: 22)),
                    Text(cal.hasTarget ? '/ ${formatThousands(cal.target!)} kcal' : 'kcal', style: t.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _macroRow(context, 'Protein', totals.protein, profile.proteinTarget, p.protein),
                    const SizedBox(height: 10),
                    _macroRow(context, 'Carbs', totals.carbs, profile.carbsTarget, p.carbs),
                    const SizedBox(height: 10),
                    _macroRow(context, 'Fat', totals.fat, profile.fatTarget, p.fat),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!cal.hasTarget)
            Text('Set your daily targets in Profile & Goals to track progress.', style: t.bodySmall)
          else
            Text(
              cal.isOver ? '${formatKcal(cal.excess!)} over target' : '${formatKcal(cal.remaining!)} remaining',
              style: t.bodySmall?.copyWith(
                color: cal.isOver ? p.warning : p.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _macroRow(BuildContext context, String label, double consumed, double? target, Color color) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: t.bodyMedium)),
        Text(
          target == null ? '${consumed.round()} g' : '${consumed.round()} / ${target.round()} g',
          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateKey(ref.watch(todayProvider));
    Widget action(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
    final p = context.palette;
    return Row(
      children: [
        action(Icons.restaurant, 'Log Food', p.accentText, () async {
          final categories = await ref.read(mealCategoriesProvider.future);
          final meal = suggestedMealCategory(DateTime.now(), categories);
          if (context.mounted) {
            context.go(Uri(path: '/diet/add', queryParameters: {'date': today, 'meal': meal}).toString());
          }
        }),
        const SizedBox(width: 10),
        action(Icons.water_drop, 'Log Water', p.water, () => showWaterSheet(context, date: today)),
        const SizedBox(width: 10),
        action(Icons.monitor_weight, 'Record Weight', p.fat, () => showWeightEntrySheet(context)),
      ],
    );
  }
}

class _WeeklyActivity extends ConsumerWidget {
  const _WeeklyActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final today = ref.watch(todayProvider);
    final plan = ref.watch(activePlanProvider).value;
    final completed = ref.watch(weekCompletedDatesProvider).value ?? const <String>{};
    final active = ref.watch(sessionControllerProvider).value;
    final days = buildWeeklyActivity(today: today, plan: plan, completedDates: completed, inProgressDate: active?.date);

    Widget dot(DayStatus s) {
      const size = 30.0;
      return switch (s) {
        DayStatus.completed => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
          child: Icon(Icons.check, size: 18, color: p.onAccent),
        ),
        DayStatus.inProgress => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: p.accent, width: 2),
          ),
          child: Icon(Icons.more_horiz, size: 16, color: p.accentText),
        ),
        DayStatus.today => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: p.accent, width: 2),
          ),
        ),
        DayStatus.planned => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: p.textMuted, width: 1.5),
          ),
        ),
        DayStatus.missed => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.elevated,
            border: Border.all(color: p.border),
          ),
          child: Icon(Icons.remove, size: 14, color: p.textMuted),
        ),
        DayStatus.rest => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: p.backgroundAlt),
          child: Icon(Icons.bedtime_outlined, size: 15, color: p.textSecondary),
        ),
        DayStatus.unplanned => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: p.border),
          ),
        ),
      };
    }

    return AppCard(
      onTap: () => context.go('/workout'),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final d in days)
                Tooltip(
                  message: '${weekdayName(d.date.weekday)}: ${d.status.description}',
                  child: Column(
                    children: [
                      dot(d.status),
                      const SizedBox(height: 6),
                      Text(
                        weekdayShort(d.date.weekday),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSameDay(d.date, today) ? FontWeight.w800 : FontWeight.w500,
                          color: isSameDay(d.date, today) ? p.accentText : p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _legend(context, p.accent, 'Done', filled: true),
              _legend(context, p.textMuted, 'Planned'),
              _legend(context, p.textSecondary, 'Rest', icon: Icons.bedtime_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String label, {bool filled = false, IconData? icon}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null)
        Icon(icon, size: 12, color: color)
      else
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : null,
            border: filled ? null : Border.all(color: color, width: 1.5),
          ),
        ),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
    ],
  );
}

class _ConsistencyCard extends ConsumerWidget {
  const _ConsistencyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final key = dateKey(today);
    final profile = ref.watch(profileProvider);
    final unit = ref.watch(settingsProvider).waterUnit;
    final totals = ref.watch(dayTotalsProvider(key)).value ?? Nutrients.zero;
    final water = (ref.watch(waterForDateProvider(key)).value ?? const <WaterLog>[]).fold<double>(
      0,
      (s, l) => s + l.ml,
    );
    final completedToday = (ref.watch(todayCompletedSessionsProvider).value ?? const []).isNotEmpty;
    final day = ref.watch(todayPlanDayProvider).value;

    final rows = <(bool, String)>[
      if (completedToday)
        (true, 'Workout completed')
      else if (day == null)
        (false, 'No workout planned today')
      else if (day.isRestDay)
        (true, 'Rest day: recovery counts too')
      else
        (false, 'Workout planned: ${day.title}'),
      if (profile.proteinTarget != null)
        TargetProgress(totals.protein, profile.proteinTarget).isReached
            ? (true, 'Protein target reached')
            : (false, 'Protein: ${totals.protein.round()} of ${profile.proteinTarget!.round()} g'),
      if (profile.calorieTarget != null)
        () {
          final c = TargetProgress(totals.calories, profile.calorieTarget);
          if (totals.calories == 0) return (false, 'No food logged yet');
          if (c.isOver) return (false, 'Calories: ${formatKcal(c.excess!)} above target');
          return (true, 'Calories within target (${formatThousands(totals.calories)} kcal)');
        }(),
      if (profile.waterTargetMl != null)
        water >= profile.waterTargetMl!
            ? (true, 'Water target reached')
            : (false, 'Water: ${formatWater(water, unit)} of ${formatWater(profile.waterTargetMl!, unit)}'),
    ];

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: p.accentText, size: 20),
              const SizedBox(width: 8),
              Text('Today so far', style: t.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          for (final (done, label) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: done ? p.accentText : p.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: t.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
