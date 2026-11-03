import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/feedback.dart';
import '../../exercises/exercise.dart';
import '../../exercises/exercise_thumb.dart';
import '../../settings/app_settings.dart';
import '../models.dart';
import '../workout_actions.dart';
import '../workout_providers.dart';
import 'add_to_plan_sheet.dart';

/// Edit one weekday of a plan: name, rest day, exercises and their targets.
class PlanDayEditorScreen extends ConsumerStatefulWidget {
  const PlanDayEditorScreen({super.key, required this.dayId});
  final int dayId;

  @override
  ConsumerState<PlanDayEditorScreen> createState() => _PlanDayEditorScreenState();
}

class _PlanDayEditorScreenState extends ConsumerState<PlanDayEditorScreen> {
  final _name = TextEditingController();
  bool _nameLoaded = false;
  Timer? _nameDebounce;
  List<PlannedExercise>? _pendingOrder;

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _name.dispose();
    super.dispose();
  }

  void _bump() => ref.read(workoutRevisionProvider.notifier).bump();

  void _onNameChanged(String value) {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 500), () async {
      await ref.read(planRepositoryProvider).updateDay(widget.dayId, name: value);
      _bump();
    });
  }

  /// [newIndex] is already adjusted for the removed item (onReorderItem).
  Future<void> _reorder(List<PlannedExercise> items, int oldIndex, int newIndex) async {
    final list = [...items];
    list.insert(newIndex, list.removeAt(oldIndex));
    setState(() => _pendingOrder = list);
    await ref.read(planRepositoryProvider).reorder(widget.dayId, list.map((e) => e.id).toList());
    _bump();
    await ref.read(planDayProvider(widget.dayId).future);
    if (mounted) setState(() => _pendingOrder = null);
  }

  Future<void> _addExercise() async {
    final exercise = await context.push<Exercise>('/workout/pick-exercise?title=Add exercise');
    if (exercise == null || !mounted) return;
    final t = defaultTargets(exercise.type);
    await runGuarded(context, () async {
      await ref
          .read(planRepositoryProvider)
          .addExercise(
            widget.dayId,
            exercise.id,
            sets: t.sets,
            minReps: t.minReps,
            maxReps: t.maxReps,
            restSeconds: ref.read(settingsProvider).defaultRestSeconds,
          );
      _bump();
    });
  }

  Future<void> _copyTo(PlanDay day) async {
    final plan = await ref.read(planRepositoryProvider).planWithDays(day.planId);
    if (plan == null || !mounted) return;
    final target = await showChoiceSheet<int>(
      context,
      title: 'Copy this workout to…',
      options: [
        for (final d in plan.days.where((d) => d.id != day.id))
          (
            value: d.id,
            label: weekdayName(d.weekday),
            subtitle: d.isRestDay ? 'Rest day' : d.title,
            icon: Icons.calendar_today_outlined,
          ),
      ],
    );
    if (target == null || !mounted) return;
    final targetDay = plan.days.firstWhere((d) => d.id == target);
    if (!targetDay.isRestDay && targetDay.exercises.isNotEmpty) {
      final ok = await showConfirmDialog(
        context,
        title: 'Replace ${weekdayName(targetDay.weekday)}?',
        message: '"${targetDay.title}" will be replaced with a copy of "${day.title}".',
        confirm: 'Replace',
      );
      if (!ok) return;
    }
    await ref.read(planRepositoryProvider).copyDay(day.id, target);
    _bump();
    if (mounted) showSnack(context, 'Copied to ${weekdayName(targetDay.weekday)}.');
  }

  Future<void> _clear(PlanDay day) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Clear ${weekdayName(day.weekday)}?',
      message: 'All exercises are removed and the day becomes a rest day. Past workouts are not affected.',
      confirm: 'Clear',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(planRepositoryProvider).clearDay(day.id);
    _name.clear();
    _bump();
  }

  @override
  Widget build(BuildContext context) {
    final dayAsync = ref.watch(planDayProvider(widget.dayId));
    final day = dayAsync.value;
    if (day != null && !_nameLoaded) {
      _name.text = day.name;
      _nameLoaded = true;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(day == null ? 'Workout day' : weekdayName(day.weekday)),
        actions: [
          if (day != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'copy') _copyTo(day);
                if (v == 'clear') _clear(day);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'copy', child: Text('Copy to another day')),
                PopupMenuItem(value: 'clear', child: Text('Clear day')),
              ],
            ),
        ],
      ),
      body: AsyncView(
        value: dayAsync,
        builder: (day) {
          if (day == null) return const EmptyState(icon: Icons.help_outline, title: 'This day no longer exists');
          final items = _pendingOrder ?? day.exercises;
          final t = Theme.of(context).textTheme;
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            buildDefaultDragHandles: false,
            itemCount: day.isRestDay ? 0 : items.length,
            onReorderItem: (a, b) => _reorder(items, a, b),
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  onChanged: _onNameChanged,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 40,
                  decoration: InputDecoration(
                    labelText: 'Workout name',
                    hintText: day.isRestDay ? 'Rest Day' : 'e.g. Chest & Triceps',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    title: const Text('Rest day'),
                    subtitle: const Text('No workout planned. Rest days never count as missed.'),
                    value: day.isRestDay,
                    onChanged: (v) async {
                      await ref.read(planRepositoryProvider).updateDay(day.id, isRestDay: v);
                      _bump();
                    },
                  ),
                ),
                if (!day.isRestDay) ...[
                  SectionTitle('Exercises', action: items.isEmpty ? null : '~${day.estimatedMinutes} min'),
                  if (items.isEmpty)
                    const EmptyState(
                      icon: Icons.fitness_center,
                      title: 'No exercises yet',
                      message: 'Add exercises from the library.',
                      compact: true,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Drag the handle to reorder. Tap an exercise to change sets, reps and rest.',
                        style: t.bodySmall,
                      ),
                    ),
                ],
              ],
            ),
            footer: day.isRestDay
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _addExercise,
                          icon: const Icon(Icons.add),
                          label: const Text('Add exercise'),
                        ),
                        const SizedBox(height: 10),
                        if (items.isNotEmpty)
                          FilledButton.icon(
                            onPressed: () => startWorkoutFromDay(context, ref, day),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start this workout'),
                          ),
                      ],
                    ),
                  ),
            itemBuilder: (context, i) {
              final pe = items[i];
              return Padding(
                key: ValueKey(pe.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                  onTap: () => showPlannedExerciseSheet(context, ref, pe),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.drag_indicator, color: context.palette.textMuted),
                        ),
                      ),
                      ExerciseThumb(exercise: pe.exercise, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pe.exercise.name, style: t.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              '${pe.targetLabel} · ${formatDurationShort(Duration(seconds: pe.restSeconds))} rest',
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () async {
                          await ref.read(planRepositoryProvider).removePlannedExercise(pe.id);
                          _bump();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Edit sets, rep range and rest for a planned exercise.
Future<void> showPlannedExerciseSheet(BuildContext context, WidgetRef ref, PlannedExercise pe) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlannedExerciseSheet(pe: pe),
    );

class _PlannedExerciseSheet extends ConsumerStatefulWidget {
  const _PlannedExerciseSheet({required this.pe});
  final PlannedExercise pe;

  @override
  ConsumerState<_PlannedExerciseSheet> createState() => _PlannedExerciseSheetState();
}

class _PlannedExerciseSheetState extends ConsumerState<_PlannedExerciseSheet> {
  final _form = GlobalKey<FormState>();
  late int _sets = widget.pe.sets;
  late int _rest = widget.pe.restSeconds;
  late final _min = TextEditingController(text: widget.pe.minReps?.toString() ?? '');
  late final _max = TextEditingController(text: widget.pe.maxReps?.toString() ?? '');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await runGuarded(context, () async {
      await ref
          .read(planRepositoryProvider)
          .updatePlannedExercise(
            widget.pe.id,
            sets: _sets,
            minReps: parseInteger(_min.text),
            maxReps: parseInteger(_max.text),
            restSeconds: _rest,
          );
      ref.read(workoutRevisionProvider.notifier).bump();
    });
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final type = widget.pe.exercise.type;
    final unit = type == ExerciseType.time ? 'seconds' : 'reps';
    String? validate(String? v) =>
        validateOptionalNumber(v, min: 0, max: type == ExerciseType.time ? 3600 : 100, label: 'Target');
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.pe.exercise.name, style: t.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('Sets', style: t.titleSmall)),
                  IconButton.outlined(
                    tooltip: 'Fewer sets',
                    onPressed: _sets > 1 ? () => setState(() => _sets--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text('$_sets', textAlign: TextAlign.center, style: t.titleLarge),
                  ),
                  IconButton.outlined(
                    tooltip: 'More sets',
                    onPressed: _sets < 20 ? () => setState(() => _sets++) : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (type != ExerciseType.distance) ...[
                const SizedBox(height: 16),
                Text('Target $unit (range)', style: t.titleSmall),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _min,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'From'),
                        validator: validate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _max,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'To'),
                        validator: (v) {
                          final base = validate(v);
                          if (base != null) return base;
                          final a = parseInteger(_min.text), b = parseInteger(v ?? '');
                          if (a != null && b != null && a > b) return 'Must be ≥ From';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text('Rest between sets', style: t.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in const [30, 45, 60, 90, 120, 150, 180, 240])
                    ChoiceChip(
                      label: Text(formatDurationShort(Duration(seconds: s))),
                      selected: _rest == s,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _rest == s ? context.palette.onAccent : context.palette.text,
                      ),
                      onSelected: (_) => setState(() => _rest = s),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
