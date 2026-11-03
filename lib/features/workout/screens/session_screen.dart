import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../rest_timer.dart';
import '../session_controller.dart';
import '../workout_actions.dart';
import '../workout_calculations.dart';
import '../workout_providers.dart';

class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionControllerProvider);
    final session = async.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Session'),
        actions: [
          if (session != null) ...[_ElapsedClock(startedAt: session.startedAt), _SessionMenu(session: session)],
        ],
      ),
      body: AsyncView(
        value: async,
        builder: (session) => session == null ? const _NoSession() : _SessionBody(session: session),
      ),
    );
  }
}

class _NoSession extends ConsumerWidget {
  const _NoSession();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    children: [
      EmptyState(
        icon: Icons.timer_off_outlined,
        title: 'No workout in progress',
        message: 'Start today\'s workout from the plan, or log a quick workout.',
        action: 'Start a quick workout',
        onAction: () => startQuickWorkout(context, ref),
      ),
      Center(
        child: TextButton(onPressed: () => context.go('/workout'), child: const Text('Go to the week plan')),
      ),
    ],
  );
}

class _ElapsedClock extends StatefulWidget {
  const _ElapsedClock({required this.startedAt});
  final DateTime startedAt;

  @override
  State<_ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<_ElapsedClock> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: 'Workout duration',
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 18, color: p.accentText),
          const SizedBox(width: 4),
          Text(
            formatClock(DateTime.now().difference(widget.startedAt)),
            style: TextStyle(
              color: p.accentText,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

enum _FinishChoice { cancel, withoutUnticked, tickAndFinish }

/// Shared by the menu and the bottom button.
Future<void> finishWorkout(BuildContext context, WidgetRef ref, WorkoutSession session) async {
  final controller = ref.read(sessionControllerProvider.notifier);
  final unticked = controller.filledButIncompleteSets;
  var choice = _FinishChoice.withoutUnticked;
  if (unticked > 0) {
    choice =
        await showDialog<_FinishChoice>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Some sets are not ticked'),
            content: Text(
              '$unticked ${unticked == 1 ? 'set has' : 'sets have'} values but ${unticked == 1 ? 'is' : 'are'} not marked done. '
              'Only ticked sets are saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, _FinishChoice.cancel),
                child: const Text('Keep going'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, _FinishChoice.withoutUnticked),
                child: const Text('Leave them out'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, _FinishChoice.tickAndFinish),
                child: const Text('Mark done'),
              ),
            ],
          ),
        ) ??
        _FinishChoice.cancel;
    if (choice == _FinishChoice.cancel) return;
    if (choice == _FinishChoice.tickAndFinish) await controller.completeFilledSets();
  }
  final current = ref.read(sessionControllerProvider).value ?? session;
  final summary = summarizeSession(current);
  if (!context.mounted) return;
  if (summary.completedSets == 0) {
    final discard = await showConfirmDialog(
      context,
      title: 'Nothing to save yet',
      message: 'No sets are marked done, so there is nothing to record. Keep going, or discard this workout?',
      confirm: 'Discard workout',
      cancel: 'Keep going',
      destructive: true,
    );
    if (discard) {
      ref.read(restTimerProvider.notifier).reset();
      await controller.discard();
      if (context.mounted) context.go('/workout');
    }
    return;
  }
  if (choice != _FinishChoice.tickAndFinish) {
    final ok = await showConfirmDialog(
      context,
      title: 'Finish workout?',
      message: '${summary.completedSets} sets across ${summary.completedExercises} exercises will be saved.',
      confirm: 'Finish',
    );
    if (!ok) return;
  }
  ref.read(restTimerProvider.notifier).reset();
  final id = await controller.finish();
  if (id != null && context.mounted) context.go('/workout/history/$id?finished=1');
}

class _SessionMenu extends ConsumerWidget {
  const _SessionMenu({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    onSelected: (v) async {
      final controller = ref.read(sessionControllerProvider.notifier);
      switch (v) {
        case 'add':
          final e = await context.push<Exercise>('/workout/pick-exercise?title=Add exercise');
          if (e != null) await controller.addExercise(e);
        case 'finish':
          if (context.mounted) await finishWorkout(context, ref, session);
        case 'discard':
          final ok = await showConfirmDialog(
            context,
            title: 'Discard this workout?',
            message: 'Everything logged in this session will be deleted. This cannot be undone.',
            confirm: 'Discard',
            destructive: true,
          );
          if (!ok) return;
          ref.read(restTimerProvider.notifier).reset();
          await controller.discard();
          if (context.mounted) context.go('/workout');
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'add', child: Text('Add exercise')),
      PopupMenuItem(value: 'finish', child: Text('Finish workout')),
      PopupMenuItem(value: 'discard', child: Text('Discard workout')),
    ],
  );
}

class _SessionBody extends ConsumerWidget {
  const _SessionBody({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final controller = ref.read(sessionControllerProvider.notifier);
    final summary = summarizeSession(session);

    if (session.exercises.isEmpty) {
      return ListView(
        padding: pagePadding,
        children: [
          Text(session.name, style: t.headlineSmall),
          EmptyState(
            icon: Icons.add_circle_outline,
            title: 'Add your first exercise',
            message: 'Pick exercises as you go. Each one starts with three sets.',
            action: 'Add exercise',
            onAction: () async {
              final e = await context.push<Exercise>('/workout/pick-exercise?title=Add exercise');
              if (e != null) await controller.addExercise(e);
            },
          ),
        ],
      );
    }

    final index = session.currentIndex.clamp(0, session.exercises.length - 1);
    final current = session.exercises[index];
    final isLast = index == session.exercises.length - 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(session.name, style: t.headlineSmall),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Text('Exercise ${index + 1} of ${session.exercises.length}', style: t.bodySmall)),
            Text('${summary.completedSets} / ${summary.totalSets} sets done', style: t.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: summary.totalSets == 0 ? 0 : summary.completedSets / summary.totalSets,
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 12),
        _ExerciseStrip(session: session, index: index),
        const SizedBox(height: 12),
        _CurrentExerciseHeader(session: session, current: current, index: index),
        const SizedBox(height: 12),
        _SetTable(session: session, current: current),
        const SizedBox(height: 12),
        _RestTimerCard(current: current),
        const SizedBox(height: 16),
        Row(
          children: [
            if (index > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => controller.goTo(index - 1),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
              ),
            if (index > 0) const SizedBox(width: 10),
            Expanded(
              child: isLast
                  ? FilledButton.icon(
                      onPressed: () => finishWorkout(context, ref, session),
                      icon: const Icon(Icons.flag),
                      label: const Text('Finish workout'),
                    )
                  : FilledButton.icon(
                      onPressed: () => controller.goTo(index + 1),
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next exercise'),
                      iconAlignment: IconAlignment.end,
                    ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => finishWorkout(context, ref, session),
            style: TextButton.styleFrom(foregroundColor: p.textSecondary),
            child: const Text('Finish workout early'),
          ),
        ],
      ],
    );
  }
}

class _ExerciseStrip extends ConsumerWidget {
  const _ExerciseStrip({required this.session, required this.index});
  final WorkoutSession session;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: session.exercises.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final e = session.exercises[i];
          final skipped = e.status == SessionExerciseStatus.skipped;
          final done = e.isDone;
          final selected = i == index;
          return InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => ref.read(sessionControllerProvider.notifier).goTo(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: done ? p.accentSoft : p.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: selected ? p.accent : p.border, width: selected ? 1.6 : 1),
              ),
              alignment: Alignment.center,
              child: Row(
                children: [
                  if (done) Icon(Icons.check, size: 15, color: p.accentText),
                  if (skipped) Icon(Icons.skip_next, size: 15, color: p.textMuted),
                  if (done || skipped) const SizedBox(width: 4),
                  Text(
                    '${i + 1}. ${e.exercise.name}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: skipped ? p.textMuted : p.text,
                      decoration: skipped ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CurrentExerciseHeader extends ConsumerWidget {
  const _CurrentExerciseHeader({required this.session, required this.current, required this.index});
  final WorkoutSession session;
  final SessionExercise current;
  final int index;

  Future<void> _menu(BuildContext context, WidgetRef ref, String action) async {
    final controller = ref.read(sessionControllerProvider.notifier);
    switch (action) {
      case 'info':
        context.push('/workout/exercise/${current.exercise.id}');
      case 'skip':
        await controller.setSkipped(current.id, true);
        if (index < session.exercises.length - 1) await controller.goTo(index + 1);
      case 'unskip':
        await controller.setSkipped(current.id, false);
      case 'replace':
        if (current.completedSets > 0) {
          final ok = await showConfirmDialog(
            context,
            title: 'Replace ${current.exercise.name}?',
            message: 'The ${current.completedSets} sets logged for it in this session will be cleared.',
            confirm: 'Replace',
          );
          if (!ok || !context.mounted) return;
        }
        final e = await context.push<Exercise>('/workout/pick-exercise?title=Replace with');
        if (e != null) await controller.replaceExercise(current.id, e);
      case 'remove':
        final ok = await showConfirmDialog(
          context,
          title: 'Remove ${current.exercise.name}?',
          message: current.completedSets > 0
              ? 'It and its ${current.completedSets} logged sets will be removed from this session.'
              : 'It will be removed from this session.',
          confirm: 'Remove',
          destructive: current.completedSets > 0,
        );
        if (ok) await controller.removeExercise(current.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final unit = ref.watch(settingsProvider).weightUnit;
    final previous =
        ref.watch(previousSetsProvider((exerciseId: current.exercise.id, sessionId: session.id))).value ?? const [];
    final skipped = current.status == SessionExerciseStatus.skipped;
    final target = describeTarget(
      current.exercise.type,
      sets: current.sets.length,
      minReps: current.minReps,
      maxReps: current.maxReps,
    );

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExerciseHero(exercise: current.exercise, height: 150, focus: true),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(current.exercise.name, style: t.titleLarge),
                    const SizedBox(height: 4),
                    MuscleSummary(exercise: current.exercise),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Exercise options',
                onSelected: (a) => _menu(context, ref, a),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'info', child: Text('How to do it')),
                  skipped
                      ? const PopupMenuItem(value: 'unskip', child: Text('Un-skip exercise'))
                      : const PopupMenuItem(value: 'skip', child: Text('Skip exercise')),
                  const PopupMenuItem(value: 'replace', child: Text('Replace exercise')),
                  const PopupMenuItem(value: 'remove', child: Text('Remove from session')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Target: $target', style: t.bodySmall),
          if (previous.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Last time: ${previous.map((s) => _setSummary(s, current.exercise.type, unit)).join(' · ')}',
              style: t.bodySmall?.copyWith(color: p.textSecondary),
            ),
          ],
          if (skipped) ...[const SizedBox(height: 8), Badge2('Skipped', color: p.warning)],
        ],
      ),
    );
  }
}

String _setSummary(SetLog s, ExerciseType type, WeightUnit unit) {
  switch (type) {
    case ExerciseType.weightReps:
      return '${formatNumber(weightForDisplay(s.weightKg ?? 0, unit))} × ${s.reps ?? 0}';
    case ExerciseType.bodyweightReps:
      final w = s.weightKg ?? 0;
      return w > 0 ? '+${formatNumber(weightForDisplay(w, unit))} × ${s.reps ?? 0}' : '${s.reps ?? 0} reps';
    case ExerciseType.time:
      return '${s.durationSeconds ?? 0} s';
    case ExerciseType.distance:
      final km = (s.distanceMeters ?? 0) / 1000;
      final min = (s.durationSeconds ?? 0) / 60;
      return '${formatNumber(km, decimals: 2)} km${min > 0 ? ' in ${formatNumber(min)} min' : ''}';
  }
}

class _SetTable extends ConsumerWidget {
  const _SetTable({required this.session, required this.current});
  final WorkoutSession session;
  final SessionExercise current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final unit = ref.watch(settingsProvider).weightUnit;
    final type = current.exercise.type;
    final headerStyle = t.labelMedium?.copyWith(fontWeight: FontWeight.w700);
    final (String colA, String? colB) = switch (type) {
      ExerciseType.weightReps => ('Weight (${unit.label})', 'Reps'),
      ExerciseType.bodyweightReps => ('Added (${unit.label})', 'Reps'),
      ExerciseType.time => ('Time (s)', null),
      ExerciseType.distance => ('Distance (km)', 'Time (min)'),
    };

    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                child: Text('Set', style: headerStyle, textAlign: TextAlign.center),
              ),
              Expanded(
                child: Text(colA, style: headerStyle, textAlign: TextAlign.center),
              ),
              if (colB != null)
                Expanded(
                  child: Text(colB, style: headerStyle, textAlign: TextAlign.center),
                ),
              SizedBox(width: 48, child: Icon(Icons.check, size: 18, color: p.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          for (final s in current.sets)
            _SetRow(
              key: ValueKey(s.id),
              set: s,
              type: type,
              restSeconds: current.restSeconds,
              minReps: current.minReps,
              maxReps: current.maxReps,
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => ref.read(sessionControllerProvider.notifier).addSet(current.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Add set'),
                ),
              ),
            ],
          ),
          if (current.sets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Swipe a set left to remove it. Tap the tick again to undo.',
                style: t.bodySmall?.copyWith(fontSize: 11.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _SetRow extends ConsumerStatefulWidget {
  const _SetRow({
    super.key,
    required this.set,
    required this.type,
    required this.restSeconds,
    this.minReps,
    this.maxReps,
  });
  final SetLog set;
  final ExerciseType type;
  final int restSeconds;
  final int? minReps;
  final int? maxReps;

  @override
  ConsumerState<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<_SetRow> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _aFocus = FocusNode();
  final _bFocus = FocusNode();
  bool _invalid = false;
  Future<void>? _saving;

  WeightUnit get _unit => ref.read(settingsProvider).weightUnit;

  @override
  void initState() {
    super.initState();
    _fill(force: true);
  }

  @override
  void didUpdateWidget(covariant _SetRow old) {
    super.didUpdateWidget(old);
    _fill(force: false);
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _aFocus.dispose();
    _bFocus.dispose();
    super.dispose();
  }

  (String, String) _textsFor(SetLog s) {
    String n(double? v, [int d = 2]) => v == null ? '' : formatNumber(v, decimals: d);
    return switch (widget.type) {
      ExerciseType.weightReps || ExerciseType.bodyweightReps => (
        s.weightKg == null ? '' : n(weightForDisplay(s.weightKg!, _unit)),
        s.reps?.toString() ?? '',
      ),
      ExerciseType.time => (s.durationSeconds?.toString() ?? '', ''),
      ExerciseType.distance => (
        s.distanceMeters == null ? '' : n(s.distanceMeters! / 1000, 3),
        s.durationSeconds == null ? '' : n(s.durationSeconds! / 60),
      ),
    };
  }

  /// Copies stored values into the fields, except into a field being edited.
  void _fill({required bool force}) {
    final (a, b) = _textsFor(widget.set);
    if (force || (!_aFocus.hasFocus && _parsedMatches(_a.text, a) == false)) _a.text = a;
    if (force || (!_bFocus.hasFocus && _parsedMatches(_b.text, b) == false)) _b.text = b;
  }

  bool _parsedMatches(String current, String stored) => parseDecimal(current) == parseDecimal(stored);

  /// Parses the fields; null when something typed is not a number.
  SetValues? _values() {
    final a = _a.text.trim(), b = _b.text.trim();
    final av = parseDecimal(a), bv = parseDecimal(b);
    if ((a.isNotEmpty && av == null) || (b.isNotEmpty && bv == null)) return null;
    switch (widget.type) {
      case ExerciseType.weightReps:
      case ExerciseType.bodyweightReps:
        if (bv != null && bv != bv.roundToDouble()) return null;
        return SetValues(weightKg: av == null ? null : weightToKg(av, _unit), reps: bv?.round());
      case ExerciseType.time:
        return SetValues(durationSeconds: av?.round());
      case ExerciseType.distance:
        return SetValues(
          distanceMeters: av == null ? null : av * 1000,
          durationSeconds: bv == null ? null : (bv * 60).round(),
        );
    }
  }

  Future<void> _save() {
    final values = _values();
    if (values == null) {
      setState(() => _invalid = true);
      return Future.value();
    }
    final future = ref.read(sessionControllerProvider.notifier).updateSet(widget.set.id, values).then((error) {
      if (mounted) setState(() => _invalid = error != null);
      if (error != null && mounted) showSnack(context, error);
    });
    _saving = future;
    return future;
  }

  Future<void> _toggle(bool value) async {
    await (_saving ?? Future.value());
    if (value) await _save();
    if (_invalid) return;
    final error = await ref.read(sessionControllerProvider.notifier).setCompleted(widget.set.id, value);
    if (!mounted) return;
    if (error != null) {
      showSnack(context, error);
      return;
    }
    if (value) {
      HapticFeedback.lightImpact();
      FocusScope.of(context).unfocus();
      ref.read(restTimerProvider.notifier).start(widget.restSeconds);
    }
  }

  Widget _field(TextEditingController c, FocusNode f, String hint, {bool decimal = true}) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: c,
        focusNode: f,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        onChanged: (_) => _save(),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          fillColor: widget.set.isCompleted ? p.accentSoft : p.backgroundAlt,
          enabledBorder: _invalid
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: p.error),
                )
              : OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: p.border),
                ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _invalid ? p.error : p.accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = widget.set;
    final repsHint = repRangeLabel(widget.minReps, widget.maxReps) ?? '—';
    final cells = switch (widget.type) {
      ExerciseType.weightReps => [
        Expanded(child: _field(_a, _aFocus, '0')),
        Expanded(child: _field(_b, _bFocus, repsHint, decimal: false)),
      ],
      ExerciseType.bodyweightReps => [
        Expanded(child: _field(_a, _aFocus, '+0')),
        Expanded(child: _field(_b, _bFocus, repsHint, decimal: false)),
      ],
      ExerciseType.time => [Expanded(child: _field(_a, _aFocus, repsHint, decimal: false))],
      ExerciseType.distance => [Expanded(child: _field(_a, _aFocus, '0.0')), Expanded(child: _field(_b, _bFocus, '0'))],
    };

    return Dismissible(
      key: ValueKey('dismiss-${s.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(color: p.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.delete_outline, color: p.error),
      ),
      confirmDismiss: (_) async {
        if (!s.isCompleted) return true;
        return showConfirmDialog(
          context,
          title: 'Remove set ${s.setNumber}?',
          message: 'This set is marked done.',
          confirm: 'Remove',
          destructive: true,
        );
      },
      onDismissed: (_) => ref.read(sessionControllerProvider.notifier).removeSet(s.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '${s.setNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            ...cells,
            SizedBox(
              width: 48,
              child: Semantics(
                label: s.isCompleted ? 'Set ${s.setNumber} done. Tap to undo.' : 'Mark set ${s.setNumber} done',
                child: Transform.scale(
                  scale: 1.25,
                  child: Checkbox(value: s.isCompleted, onChanged: (v) => _toggle(v ?? false)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestTimerCard extends ConsumerWidget {
  const _RestTimerCard({required this.current});
  final SessionExercise current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final timer = ref.watch(restTimerProvider);
    final notifier = ref.read(restTimerProvider.notifier);
    final idle = timer.status == RestStatus.idle;
    final finished = timer.status == RestStatus.finished;
    final running = timer.status == RestStatus.running;
    final seconds = idle ? current.restSeconds : timer.remainingSeconds;

    void adjust(int delta) {
      if (idle || finished) {
        ref
            .read(sessionControllerProvider.notifier)
            .setRestSeconds(current.id, (current.restSeconds + delta).clamp(5, 3600));
      } else {
        notifier.adjust(delta);
      }
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Rest timer', style: t.titleSmall),
              const Spacer(),
              if (!idle)
                TextButton(
                  onPressed: notifier.reset,
                  style: TextButton.styleFrom(foregroundColor: p.textSecondary, visualDensity: VisualDensity.compact),
                  child: const Text('Reset'),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      finished ? 'Rest over' : formatClock(Duration(seconds: seconds)),
                      style: t.headlineMedium?.copyWith(
                        color: p.accentText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontSize: finished ? 24 : 32,
                      ),
                    ),
                    if (!idle && !finished)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(value: timer.progress, minHeight: 4),
                        ),
                      ),
                    if (idle) Text('Starts when you tick a set', style: t.bodySmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove 15 seconds',
                onPressed: () => adjust(-15),
                icon: const Text('−15', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                tooltip: 'Add 15 seconds',
                onPressed: () => adjust(15),
                icon: const Text('+15', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                tooltip: running ? 'Pause' : (timer.status == RestStatus.paused ? 'Resume' : 'Start rest'),
                iconSize: 28,
                style: IconButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                  fixedSize: const Size(52, 52),
                ),
                onPressed: switch (timer.status) {
                  RestStatus.running => notifier.pause,
                  RestStatus.paused => notifier.resume,
                  _ => () => notifier.start(current.restSeconds),
                },
                icon: Icon(running ? Icons.pause : Icons.play_arrow),
              ),
            ],
          ),
          if (running || timer.status == RestStatus.paused)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: notifier.skip,
                style: OutlinedButton.styleFrom(minimumSize: const Size(80, 36)),
                child: const Text('Skip'),
              ),
            ),
        ],
      ),
    );
  }
}
