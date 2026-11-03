import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../../exercises/exercise_library_view.dart';
import '../models.dart';
import '../session_controller.dart';
import '../workout_actions.dart';
import '../workout_providers.dart';
import 'add_to_plan_sheet.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/workout/exercise/new'),
              icon: const Icon(Icons.add),
              label: const Text('Custom exercise'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Workout Plan', style: Theme.of(context).textTheme.headlineSmall)),
                  IconButton(
                    tooltip: 'Workout history',
                    icon: const Icon(Icons.history),
                    onPressed: () => context.go('/workout/history'),
                  ),
                  IconButton(
                    tooltip: 'Manage plans',
                    icon: const Icon(Icons.edit_calendar_outlined),
                    onPressed: () => context.go('/workout/plans'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: PillTabs(
                labels: const ['Week Plan', 'Exercise Library'],
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: _tab == 0
                  ? const _WeekPlanView()
                  : ExerciseLibraryView(
                      onTap: (e) => context.push('/workout/exercise/${e.id}'),
                      trailingBuilder: (e) => IconButton(
                        tooltip: 'Add to workout',
                        icon: Icon(Icons.add_box_rounded, color: context.palette.accentText, size: 30),
                        onPressed: () => showAddToPlanSheet(context, ref, e),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekPlanView extends ConsumerWidget {
  const _WeekPlanView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final plan = ref.watch(activePlanProvider);
    final completed = ref.watch(weekCompletedDatesProvider).value ?? const <String>{};
    final active = ref.watch(sessionControllerProvider).value;
    final monday = startOfWeek(today);

    return AsyncView(
      value: plan,
      onRetry: () => ref.invalidate(activePlanProvider),
      builder: (plan) {
        if (plan == null) {
          return EmptyState(
            icon: Icons.event_note,
            title: 'No active plan',
            message: 'Create a weekly plan, or start a quick workout and add exercises as you go.',
            action: 'Manage plans',
            onAction: () => context.go('/workout/plans'),
          );
        }
        final todayDay = plan.dayFor(today.weekday);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            if (active != null) ...[
              AppCard(
                highlighted: true,
                onTap: () => context.go('/workout/session'),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: p.accentText),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Workout in progress: ${active.name}', style: t.titleSmall)),
                    Text('Resume', style: t.labelLarge?.copyWith(color: p.accentText)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Flexible(
                  child: Text(plan.plan.name, style: t.titleMedium, overflow: TextOverflow.ellipsis),
                ),
                if (plan.plan.isSample) ...[const SizedBox(width: 8), Badge2('Sample', color: p.warning)],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${plan.trainingDays} training days · '
              '${plan.plan.isSample ? 'A generic starting point. Tap a day to change it.' : 'Tap a day to edit it.'}',
              style: t.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final day in plan.days) ...[
              _DayRow(
                day: day,
                isToday: day.weekday == today.weekday,
                done: completed.contains(dateKey(addDays(monday, day.weekday - 1))),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            if (!todayDay.isRestDay && todayDay.exercises.isNotEmpty && active == null)
              FilledButton.icon(
                onPressed: () => startWorkoutFromDay(context, ref, todayDay),
                icon: const Icon(Icons.play_arrow),
                label: Text("Start today's workout"),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => startQuickWorkout(context, ref),
                    icon: const Icon(Icons.bolt, size: 20),
                    label: const Text('Quick workout'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/workout/plans'),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: const Text('Edit plans'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.isToday, required this.done});
  final PlanDay day;
  final bool isToday;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return AppCard(
      highlighted: isToday,
      onTap: () => context.go('/workout/day/${day.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              weekdayShort(day.weekday),
              style: t.titleMedium?.copyWith(color: isToday ? p.accentText : p.text),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.title, style: t.titleSmall),
                const SizedBox(height: 2),
                Text(
                  day.isRestDay
                      ? (day.name.trim().isEmpty || day.name == 'Rest Day' ? 'Recovery' : 'Rest day')
                      : '${day.exercises.length} exercises${day.exercises.isEmpty ? '' : ' · ~${day.estimatedMinutes} min'}',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          if (done)
            Icon(Icons.check_circle, color: p.accentText)
          else if (day.isRestDay)
            Icon(Icons.bedtime_outlined, color: p.textMuted)
          else
            Icon(Icons.chevron_right, color: p.textMuted),
        ],
      ),
    );
  }
}
