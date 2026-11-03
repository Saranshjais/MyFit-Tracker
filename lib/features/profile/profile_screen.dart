import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../progress/body_repository.dart';
import '../settings/app_settings.dart';
import 'profile_widgets.dart';
import 'target_calculator.dart';
import 'user_profile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _height = HeightInputController();
  final _weight = TextEditingController();
  final _targetWeight = TextEditingController();
  final _duration = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _water = TextEditingController();

  Sex? _sex;
  FitnessGoal? _goal;
  ActivityLevel? _activity;
  int? _days;
  TrainingExperience? _experience;
  DietPreference? _diet;
  bool _targetsManual = false;
  double? _loadedWeightKg;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pr = ref.read(profileProvider);
    final s = ref.read(settingsProvider);
    final latest = await ref.read(bodyRepositoryProvider).latestWeight();
    _name.text = pr.name;
    _age.text = pr.age?.toString() ?? '';
    _height.set(pr.heightCm);
    _loadedWeightKg = latest?.weightKg;
    _weight.text = latest == null ? '' : formatNumber(weightForDisplay(latest.weightKg, s.weightUnit), decimals: 1);
    _targetWeight.text = pr.targetWeightKg == null
        ? ''
        : formatNumber(weightForDisplay(pr.targetWeightKg!, s.weightUnit), decimals: 1);
    _duration.text = pr.workoutDurationMin?.toString() ?? '';
    _calories.text = pr.calorieTarget?.round().toString() ?? '';
    _protein.text = pr.proteinTarget?.round().toString() ?? '';
    _carbs.text = pr.carbsTarget?.round().toString() ?? '';
    _fat.text = pr.fatTarget?.round().toString() ?? '';
    _water.text = pr.waterTargetMl?.round().toString() ?? '';
    _sex = pr.sex;
    _goal = pr.goal;
    _activity = pr.activityLevel;
    _days = pr.weeklyTrainingDays;
    _experience = pr.experience;
    _diet = pr.dietPreference;
    _targetsManual = pr.targetsManual;
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in [_name, _age, _weight, _targetWeight, _duration, _calories, _protein, _carbs, _fat, _water]) {
      c.dispose();
    }
    _height.dispose();
    super.dispose();
  }

  WeightUnit get _unit => ref.read(settingsProvider).weightUnit;
  LengthUnit get _lengthUnit => ref.read(settingsProvider).lengthUnit;

  double? get _weightKg {
    final v = parseDecimal(_weight.text);
    return v == null ? null : weightToKg(v, _unit);
  }

  TargetInputs get _inputs => TargetInputs(
    age: parseInteger(_age.text),
    sex: _sex,
    heightCm: _height.valueCm(_lengthUnit),
    weightKg: _weightKg,
    activity: _activity,
    goal: _goal,
  );

  void _applyEstimate(TargetEstimate e) {
    setState(() {
      _calories.text = e.calories.round().toString();
      _protein.text = e.protein.round().toString();
      _carbs.text = e.carbs.round().toString();
      _fat.text = e.fat.round().toString();
      _targetsManual = false;
    });
    showSnack(context, 'Estimate applied. Tap Save to keep it.');
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final calories = parseDecimal(_calories.text);
    final targetWeight = parseDecimal(_targetWeight.text);
    final profile = UserProfile(
      name: _name.text,
      age: parseInteger(_age.text),
      sex: _sex,
      heightCm: _height.valueCm(_lengthUnit),
      targetWeightKg: targetWeight == null ? null : weightToKg(targetWeight, _unit),
      goal: _goal,
      activityLevel: _activity,
      weeklyTrainingDays: _days,
      workoutDurationMin: parseInteger(_duration.text),
      experience: _experience,
      dietPreference: _diet,
      calorieTarget: calories,
      proteinTarget: parseDecimal(_protein.text),
      carbsTarget: parseDecimal(_carbs.text),
      fatTarget: parseDecimal(_fat.text),
      waterTargetMl: parseDecimal(_water.text),
      targetsManual: _targetsManual,
    );
    await runGuarded(context, () async {
      await ref.read(profileProvider.notifier).save(profile);
      final kg = _weightKg;
      // A changed current weight is recorded as today's weigh-in.
      if (kg != null && (_loadedWeightKg == null || (kg - _loadedWeightKg!).abs() > 0.01)) {
        await ref.read(bodyRepositoryProvider).recordWeight(dateKey(ref.read(todayProvider)), kg);
        ref.read(bodyRevisionProvider.notifier).bump();
        _loadedWeightKg = kg;
      }
    }, success: 'Profile saved');
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final settings = ref.watch(settingsProvider);
    final estimate = TargetCalculator.estimate(_inputs);
    final missing = TargetCalculator.missingInputs(_inputs);
    final weightRange = settings.weightUnit == WeightUnit.kg ? (25.0, 300.0) : (55.0, 660.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Goals'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _loaded ? _save : null,
              style: FilledButton.styleFrom(minimumSize: const Size(64, 38)),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: !_loaded
          ? const LoadingView()
          : Form(
              key: _form,
              onChanged: () => setState(() {}),
              child: ListView(
                padding: pagePadding,
                children: [
                  const SectionTitle('Personal information', padding: EdgeInsets.only(top: 4, bottom: 10)),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DecimalField(
                          controller: _age,
                          label: 'Age',
                          suffix: 'years',
                          decimal: false,
                          validator: (v) => validateOptionalNumber(v, min: 13, max: 100, label: 'Age'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: HeightInput(
                          controller: _height,
                          unit: settings.lengthUnit,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DecimalField(
                          controller: _weight,
                          label: 'Current weight',
                          suffix: settings.weightUnit.label,
                          validator: (v) =>
                              validateOptionalNumber(v, min: weightRange.$1, max: weightRange.$2, label: 'Weight'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DecimalField(
                          controller: _targetWeight,
                          label: 'Target weight',
                          suffix: settings.weightUnit.label,
                          validator: (v) =>
                              validateOptionalNumber(v, min: weightRange.$1, max: weightRange.$2, label: 'Weight'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Changing current weight records a weigh-in for today.', style: t.bodySmall),
                  _label('Sex (used by the calorie formula)'),
                  ChoiceChips<Sex>(
                    values: Sex.values,
                    selected: _sex,
                    label: (s) => s.label,
                    onSelected: (s) => setState(() => _sex = s),
                  ),
                  const SectionTitle('Fitness goal'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: RadioGroup<FitnessGoal>(
                      groupValue: _goal,
                      onChanged: (g) => setState(() => _goal = g),
                      child: Column(
                        children: [
                          for (final g in FitnessGoal.values)
                            RadioListTile<FitnessGoal>(value: g, title: Text(g.label), dense: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LabeledDropdown<ActivityLevel>(
                    label: 'Activity level',
                    value: _activity,
                    hint: 'Choose',
                    items: ActivityLevel.values,
                    itemLabel: (a) => '${a.label}: ${a.description}',
                    onChanged: (a) => setState(() => _activity = a),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: LabeledDropdown<int>(
                          label: 'Gym days / week',
                          value: _days,
                          hint: 'Choose',
                          items: const [1, 2, 3, 4, 5, 6, 7],
                          onChanged: (d) => setState(() => _days = d),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DecimalField(
                          controller: _duration,
                          label: 'Usual workout',
                          suffix: 'min',
                          decimal: false,
                          validator: (v) => validateOptionalNumber(v, min: 10, max: 300, label: 'Duration'),
                        ),
                      ),
                    ],
                  ),
                  _label('Experience'),
                  ChoiceChips<TrainingExperience>(
                    values: TrainingExperience.values,
                    selected: _experience,
                    label: (e) => e.label,
                    onSelected: (e) => setState(() => _experience = e),
                  ),
                  _label('Diet preference'),
                  ChoiceChips<DietPreference>(
                    values: DietPreference.values,
                    selected: _diet,
                    label: (d) => d.label,
                    onSelected: (d) => setState(() => _diet = d),
                  ),
                  const SectionTitle('Daily calorie & macro target'),
                  if (estimate == null)
                    AppCard(
                      color: p.backgroundAlt,
                      child: Text(
                        'For an individual estimate, add: ${missing.join(', ')}. You can also type your own targets.',
                        style: t.bodySmall,
                      ),
                    )
                  else ...[
                    TargetExplanation(estimate: estimate, goal: _goal!),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _applyEstimate(estimate),
                      icon: const Icon(Icons.calculate_outlined),
                      label: Text('Use estimate: ${formatKcal(estimate.calories)}'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TargetFields(
                    calories: _calories,
                    protein: _protein,
                    carbs: _carbs,
                    fat: _fat,
                    onChanged: () => _targetsManual = true,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Targets only change when you change them here. Review them after a few weeks of weight data rather than reacting to daily changes.',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  DecimalField(
                    controller: _water,
                    label: 'Daily water target',
                    suffix: 'ml',
                    decimal: false,
                    helper: 'Optional. Needs vary with body size, climate and activity.',
                    validator: (v) => validateOptionalNumber(v, min: 500, max: 8000, label: 'Water target'),
                  ),
                ],
              ),
            ),
    );
  }
}
