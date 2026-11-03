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
import '../profile/profile_widgets.dart';
import '../profile/target_calculator.dart';
import '../profile/user_profile.dart';
import '../progress/body_repository.dart';
import '../settings/app_settings.dart';
import '../workout/data/sample_plans.dart';
import '../workout/workout_providers.dart';

/// Short first-launch setup. Only the name is required; everything else can
/// be skipped and filled in later from Profile & Goals.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 4;
  int _step = 0;
  bool _saving = false;
  final _formKeys = List.generate(_steps, (_) => GlobalKey<FormState>());

  final _name = TextEditingController();
  final _age = TextEditingController();
  final _height = HeightInputController();
  final _weight = TextEditingController();
  final _targetWeight = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _water = TextEditingController();

  WeightUnit _weightUnit = WeightUnit.kg;
  LengthUnit _lengthUnit = LengthUnit.cm;
  Sex? _sex;
  FitnessGoal? _goal;
  ActivityLevel? _activity;
  int _trainingDays = 4;
  TrainingExperience? _experience;
  DietPreference? _diet = DietPreference.vegetarian;
  bool _targetsEdited = false;

  @override
  void dispose() {
    for (final c in [_name, _age, _weight, _targetWeight, _calories, _protein, _carbs, _fat, _water]) {
      c.dispose();
    }
    _height.dispose();
    super.dispose();
  }

  double? get _weightKg {
    final v = parseDecimal(_weight.text);
    return v == null ? null : weightToKg(v, _weightUnit);
  }

  TargetInputs get _inputs => TargetInputs(
    age: parseInteger(_age.text),
    sex: _sex,
    heightCm: _height.valueCm(_lengthUnit),
    weightKg: _weightKg,
    activity: _activity,
    goal: _goal,
  );

  void _fillTargetsFromEstimate() {
    if (_targetsEdited) return;
    final e = TargetCalculator.estimate(_inputs);
    if (e == null) return;
    _calories.text = e.calories.round().toString();
    _protein.text = e.protein.round().toString();
    _carbs.text = e.carbs.round().toString();
    _fat.text = e.fat.round().toString();
  }

  void _next() {
    if (!_formKeys[_step].currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (_step == 2) _fillTargetsFromEstimate();
    if (_step < _steps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final ok = await runGuarded(context, () async {
      final today = ref.read(todayProvider);
      final calories = parseDecimal(_calories.text);
      final profile = UserProfile(
        name: _name.text.trim(),
        age: parseInteger(_age.text),
        sex: _sex,
        heightCm: _height.valueCm(_lengthUnit),
        targetWeightKg: parseDecimal(_targetWeight.text) == null
            ? null
            : weightToKg(parseDecimal(_targetWeight.text)!, _weightUnit),
        goal: _goal,
        activityLevel: _activity,
        weeklyTrainingDays: _trainingDays,
        experience: _experience,
        dietPreference: _diet,
        workoutDurationMin: 60,
        calorieTarget: calories,
        proteinTarget: calories == null ? null : parseDecimal(_protein.text),
        carbsTarget: calories == null ? null : parseDecimal(_carbs.text),
        fatTarget: calories == null ? null : parseDecimal(_fat.text),
        waterTargetMl: parseDecimal(_water.text),
        targetsManual: _targetsEdited,
      );
      await ref.read(profileProvider.notifier).save(profile);
      final kg = _weightKg;
      if (kg != null) {
        await ref.read(bodyRepositoryProvider).recordWeight(dateKey(today), kg);
        ref.read(bodyRevisionProvider.notifier).bump();
      }
      final sampleDays = _trainingDays.clamp(SamplePlans.supportedDays.first, SamplePlans.supportedDays.last);
      if (sampleDays != SamplePlans.defaultDays) {
        await ref.read(planRepositoryProvider).replaceSamplePlan(sampleDays);
        ref.read(workoutRevisionProvider.notifier).bump();
      }
      await ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(weightUnit: _weightUnit, lengthUnit: _lengthUnit, onboardingCompleted: true));
    });
    if (!ok && mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      tooltip: 'Back',
                      onPressed: _saving ? null : () => setState(() => _step--),
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: (_step + 1) / _steps, minHeight: 5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${_step + 1} of $_steps', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKeys[_step],
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: switch (_step) {
                    0 => _welcomeStep(),
                    1 => _bodyStep(),
                    2 => _goalStep(),
                    _ => _targetStep(),
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _next,
                  child: Text(_saving ? 'Saving…' : (_step == _steps - 1 ? 'Finish setup' : 'Continue')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String title, String subtitle) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.headlineSmall),
          const SizedBox(height: 6),
          Text(subtitle, style: t.bodyMedium?.copyWith(color: context.palette.textSecondary, height: 1.4)),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );

  List<Widget> _welcomeStep() => [
    const SizedBox(height: 12),
    Icon(Icons.fitness_center, size: 44, color: context.palette.accentText),
    const SizedBox(height: 16),
    _title(
      'Welcome to MyFit Tracker',
      'Track workouts, food and progress. Everything is stored only on this phone: '
          'no account, no ads, no internet needed.',
    ),
    TextFormField(
      controller: _name,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Your name'),
      validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null,
      onFieldSubmitted: (_) => _next(),
    ),
  ];

  List<Widget> _bodyStep() => [
    _title(
      'About you',
      'Used to estimate your calorie needs. All fields are optional, but the estimate needs age, sex, height and weight.',
    ),
    _label('Units'),
    Row(
      children: [
        Expanded(
          child: SegmentedButton<WeightUnit>(
            segments: const [
              ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
              ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
            ],
            selected: {_weightUnit},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              final kg = _weightKg;
              _weightUnit = s.first;
              if (kg != null) _weight.text = formatNumber(weightForDisplay(kg, _weightUnit));
            }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SegmentedButton<LengthUnit>(
            segments: const [
              ButtonSegment(value: LengthUnit.cm, label: Text('cm')),
              ButtonSegment(value: LengthUnit.ftIn, label: Text('ft/in')),
            ],
            selected: {_lengthUnit},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              final cm = _height.valueCm(_lengthUnit);
              _lengthUnit = s.first;
              _height.set(cm);
            }),
          ),
        ),
      ],
    ),
    _label('Sex'),
    ChoiceChips<Sex>(
      values: Sex.values,
      selected: _sex,
      label: (s) => s.label,
      onSelected: (s) => setState(() => _sex = s),
    ),
    const SizedBox(height: 6),
    Text(
      'The calorie formula has separate versions for male and female bodies.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    const SizedBox(height: 20),
    DecimalField(
      controller: _age,
      label: 'Age',
      suffix: 'years',
      decimal: false,
      validator: (v) => validateOptionalNumber(v, min: 13, max: 100, label: 'Age'),
    ),
    const SizedBox(height: 12),
    HeightInput(controller: _height, unit: _lengthUnit),
    const SizedBox(height: 12),
    DecimalField(
      controller: _weight,
      label: 'Current weight',
      suffix: _weightUnit.label,
      validator: (v) => validateOptionalNumber(
        v,
        min: _weightUnit == WeightUnit.kg ? 25 : 55,
        max: _weightUnit == WeightUnit.kg ? 300 : 660,
        label: 'Weight',
      ),
    ),
    const SizedBox(height: 12),
    DecimalField(
      controller: _targetWeight,
      label: 'Target weight (optional)',
      suffix: _weightUnit.label,
      validator: (v) => validateOptionalNumber(
        v,
        min: _weightUnit == WeightUnit.kg ? 25 : 55,
        max: _weightUnit == WeightUnit.kg ? 300 : 660,
        label: 'Weight',
      ),
    ),
  ];

  List<Widget> _goalStep() => [
    _title('Your training', 'This sets up a sample plan you can change at any time.'),
    _label('Main goal'),
    ChoiceChips<FitnessGoal>(
      values: FitnessGoal.values,
      selected: _goal,
      label: (g) => g.label,
      onSelected: (g) => setState(() => _goal = g),
    ),
    _label('Activity level (outside planned workouts too)'),
    RadioGroup<ActivityLevel>(
      groupValue: _activity,
      onChanged: (v) => setState(() => _activity = v),
      child: Column(
        children: [
          for (final a in ActivityLevel.values)
            RadioListTile<ActivityLevel>(
              value: a,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(a.label),
              subtitle: Text(a.description),
            ),
        ],
      ),
    ),
    _label('Gym days per week: $_trainingDays'),
    Slider(
      value: _trainingDays.toDouble(),
      min: 1,
      max: 7,
      divisions: 6,
      label: '$_trainingDays',
      onChanged: (v) => setState(() => _trainingDays = v.round()),
    ),
    if (_trainingDays < 3 || _trainingDays > 6)
      Text(
        'Sample plans cover 3–6 days, so you will get the ${_trainingDays < 3 ? '3' : '6'}-day sample. Edit it to match your week.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    _label('Experience'),
    ChoiceChips<TrainingExperience>(
      values: TrainingExperience.values,
      selected: _experience,
      label: (e) => e.label,
      onSelected: (e) => setState(() => _experience = e),
    ),
    _label('Diet'),
    ChoiceChips<DietPreference>(
      values: DietPreference.values,
      selected: _diet,
      label: (d) => d.label,
      onSelected: (d) => setState(() => _diet = d),
    ),
  ];

  List<Widget> _targetStep() {
    final estimate = TargetCalculator.estimate(_inputs);
    final missing = TargetCalculator.missingInputs(_inputs);
    return [
      _title('Daily targets', 'Used on the dashboard and diet screen. You can change them later.'),
      if (estimate == null)
        AppCard(
          color: context.palette.backgroundAlt,
          child: Text(
            'An individual estimate needs: ${missing.join(', ')}. Go back to add them, type your own targets below, '
            'or leave them empty and set them later in Profile & Goals.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        )
      else
        TargetExplanation(estimate: estimate, goal: _goal!),
      const SizedBox(height: 16),
      TargetFields(
        calories: _calories,
        protein: _protein,
        carbs: _carbs,
        fat: _fat,
        onChanged: () => _targetsEdited = true,
      ),
      const SizedBox(height: 16),
      DecimalField(
        controller: _water,
        label: 'Water target (optional)',
        suffix: 'ml',
        decimal: false,
        helper: 'Needs vary with body size, climate and activity. Set what suits you.',
        validator: (v) => validateOptionalNumber(v, min: 500, max: 8000, label: 'Water target'),
      ),
    ];
  }
}
