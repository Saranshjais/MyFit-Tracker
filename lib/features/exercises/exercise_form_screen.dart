import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import 'exercise.dart';
import 'exercise_repository.dart';
import 'muscle_picker.dart';
import 'muscles.dart';

/// Create a custom exercise, or edit any exercise. Editing keeps the id, so
/// plans and history stay attached after a rename. Pops with the id.
class ExerciseFormScreen extends ConsumerStatefulWidget {
  const ExerciseFormScreen({super.key, this.exerciseId});
  final int? exerciseId;

  @override
  ConsumerState<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends ConsumerState<ExerciseFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _instructions = TextEditingController();
  String _muscle = 'Chest';
  String _equipment = 'Dumbbell';
  ExerciseType _type = ExerciseType.weightReps;
  Set<Muscle> _targets = {};
  Set<Muscle> _assists = {};
  String? _muscleError;

  /// Once the user picks a group by hand, choosing muscles no longer changes it.
  bool _groupTouched = false;
  Exercise? _original;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.exerciseId != null) {
      final e = await ref.read(exerciseRepositoryProvider).byId(widget.exerciseId!);
      if (e != null) {
        _original = e;
        _name.text = e.name;
        _description.text = e.description;
        _instructions.text = e.instructions.join('\n');
        _muscle = e.muscle;
        _equipment = e.equipment;
        _type = e.type;
        _targets = e.targetMuscles.toSet();
        _assists = e.assistMuscles.toSet();
        _groupTouched = true;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _instructions.dispose();
    super.dispose();
  }

  /// Muscles in catalogue order, so lists read consistently.
  List<Muscle> _ordered(Set<Muscle> set) => Muscle.values.where(set.contains).toList();

  Future<void> _save() async {
    final valid = _form.currentState!.validate();
    if (_targets.isEmpty) setState(() => _muscleError = 'Choose at least one main muscle.');
    if (!valid || _targets.isEmpty) return;
    final repo = ref.read(exerciseRepositoryProvider);
    final assists = _ordered(_assists);
    final e = Exercise(
      id: _original?.id ?? 0,
      name: _name.text,
      muscle: _muscle,
      equipment: _equipment,
      type: _type,
      secondaryMuscles: Exercise.secondaryGroupsFor(_muscle, assists),
      targetMuscles: _ordered(_targets),
      assistMuscles: assists,
      description: _description.text,
      instructions: _instructions.text.split('\n'),
      isCustom: _original?.isCustom ?? true,
      isArchived: _original?.isArchived ?? false,
    );
    int? id;
    final ok = await runGuarded(context, () async {
      if (_original == null) {
        id = await repo.create(e);
      } else {
        await repo.update(e);
        id = e.id;
      }
      ref.read(workoutRevisionProvider.notifier).bump();
    });
    if (ok && mounted) context.pop<int>(id);
  }

  @override
  Widget build(BuildContext context) {
    final muscles = {...muscleGroups, _muscle}.toList();
    final equipment = {...equipmentTypes, _equipment}.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_original == null ? 'New exercise' : 'Edit exercise'),
        actions: [TextButton(onPressed: _loading ? null : _save, child: const Text('Save'))],
      ),
      body: _loading
          ? const LoadingView()
          : Form(
              key: _form,
              child: ListView(
                padding: pagePadding,
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'Exercise name', counterText: ''),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                  LabeledDropdown<String>(
                    label: 'Main muscle group',
                    value: _muscle,
                    items: muscles,
                    onChanged: (v) => setState(() {
                      _muscle = v ?? _muscle;
                      _groupTouched = true;
                    }),
                  ),
                  const SizedBox(height: 12),
                  LabeledDropdown<String>(
                    label: 'Equipment',
                    value: _equipment,
                    items: equipment,
                    onChanged: (v) => setState(() => _equipment = v ?? _equipment),
                  ),
                  const SizedBox(height: 12),
                  LabeledDropdown<ExerciseType>(
                    label: 'How sets are logged',
                    value: _type,
                    items: ExerciseType.values,
                    itemLabel: (t) => t.label,
                    onChanged: (v) => setState(() => _type = v ?? _type),
                  ),
                  const SizedBox(height: 6),
                  Text(switch (_type) {
                    ExerciseType.weightReps => 'Uses external weight. Counts toward lifted volume.',
                    ExerciseType.bodyweightReps =>
                      'Bodyweight reps. Added weight is optional and only that load counts toward volume.',
                    ExerciseType.time => 'Logged as a hold time in seconds.',
                    ExerciseType.distance => 'Logged as distance and time.',
                  }, style: Theme.of(context).textTheme.bodySmall),
                  const SectionTitle('Muscles worked'),
                  MusclePicker(
                    targets: _targets,
                    assists: _assists,
                    error: _muscleError,
                    onChanged: (t, a) => setState(() {
                      _targets = t;
                      _assists = a;
                      _muscleError = null;
                      if (!_groupTouched && t.isNotEmpty) _muscle = _ordered(t).first.part.label;
                    }),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _description,
                    maxLines: 2,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Short description (optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _instructions,
                    maxLines: 6,
                    minLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Instructions (optional)',
                      helperText: 'One step per line.',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
