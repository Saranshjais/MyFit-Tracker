import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/utils/format.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/inputs.dart';
import 'target_calculator.dart';
import 'user_profile.dart';

/// Holds the text fields for a height typed in cm or in feet and inches.
class HeightInputController {
  final cm = TextEditingController();
  final feet = TextEditingController();
  final inches = TextEditingController();

  void set(double? heightCm) {
    if (heightCm == null) return;
    cm.text = formatNumber(heightCm, decimals: 0);
    final ftIn = cmToFtIn(heightCm);
    feet.text = '${ftIn.feet}';
    inches.text = formatNumber(ftIn.inches, decimals: 0);
  }

  double? valueCm(LengthUnit unit) {
    if (unit == LengthUnit.cm) return parseDecimal(cm.text);
    final ft = parseInteger(feet.text);
    final inch = parseDecimal(inches.text) ?? 0;
    if (ft == null) return null;
    return ftInToCm(ft, inch);
  }

  void dispose() {
    cm.dispose();
    feet.dispose();
    inches.dispose();
  }
}

class HeightInput extends StatelessWidget {
  const HeightInput({super.key, required this.controller, required this.unit, this.onChanged, this.required = false});
  final HeightInputController controller;
  final LengthUnit unit;
  final VoidCallback? onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    if (unit == LengthUnit.cm) {
      return DecimalField(
        controller: controller.cm,
        label: 'Height',
        suffix: 'cm',
        onChanged: (_) => onChanged?.call(),
        validator: (v) => (v ?? '').trim().isEmpty
            ? (required ? 'Enter your height' : null)
            : validateRequiredNumber(v, min: 100, max: 250, label: 'Height'),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DecimalField(
            controller: controller.feet,
            label: 'Height',
            suffix: 'ft',
            decimal: false,
            onChanged: (_) => onChanged?.call(),
            validator: (v) => (v ?? '').trim().isEmpty
                ? (required ? 'Enter feet' : null)
                : validateRequiredNumber(v, min: 3, max: 8, label: 'Feet'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DecimalField(
            controller: controller.inches,
            label: '',
            suffix: 'in',
            onChanged: (_) => onChanged?.call(),
            validator: (v) => validateOptionalNumber(v, min: 0, max: 11.9, label: 'Inches'),
          ),
        ),
      ],
    );
  }
}

/// Explains how a calorie target was estimated.
class TargetExplanation extends StatelessWidget {
  const TargetExplanation({super.key, required this.estimate, required this.goal});
  final TargetEstimate estimate;
  final FitnessGoal goal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final adj = estimate.adjustment.round();
    return AppCard(
      color: p.backgroundAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How this estimate works', style: t.titleSmall),
          const SizedBox(height: 8),
          _line(context, 'Resting energy (BMR, Mifflin–St Jeor)', formatKcal(estimate.bmr)),
          _line(context, 'Estimated maintenance (× activity)', formatKcal(estimate.tdee)),
          _line(
            context,
            'Change for "${goal.label}"',
            adj == 0 ? 'none' : '${adj > 0 ? '+' : '−'}${formatThousands(adj.abs().toDouble())} kcal',
          ),
          _line(context, 'Protein', '${formatNumber(estimate.proteinPerKg)} g per kg of body weight'),
          _line(context, 'Fat', 'about 25% of calories'),
          const SizedBox(height: 8),
          if (estimate.flooredAtMinimum)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'The deficit was reduced so the target stays above a safe minimum.',
                style: t.bodySmall?.copyWith(color: p.warning),
              ),
            ),
          Text(
            'These are estimates from a standard formula, not measurements or medical advice. '
            'Review them after a few weeks of weight data and adjust if needed.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: t.bodySmall)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: t.bodySmall?.copyWith(color: context.palette.text, fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// Calorie and macro target fields.
class TargetFields extends StatelessWidget {
  const TargetFields({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.onChanged,
  });

  final TextEditingController calories;
  final TextEditingController protein;
  final TextEditingController carbs;
  final TextEditingController fat;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    String? kcal(String? v) => validateOptionalNumber(v, min: 800, max: 6000, label: 'Calories');
    String? grams(String? v) => validateOptionalNumber(v, min: 0, max: 800, label: 'Amount');
    return Column(
      children: [
        DecimalField(
          controller: calories,
          label: 'Daily calories',
          suffix: 'kcal',
          decimal: false,
          validator: kcal,
          onChanged: (_) => onChanged?.call(),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DecimalField(
                controller: protein,
                label: 'Protein',
                suffix: 'g',
                decimal: false,
                validator: grams,
                onChanged: (_) => onChanged?.call(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DecimalField(
                controller: carbs,
                label: 'Carbs',
                suffix: 'g',
                decimal: false,
                validator: grams,
                onChanged: (_) => onChanged?.call(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DecimalField(
                controller: fat,
                label: 'Fat',
                suffix: 'g',
                decimal: false,
                validator: grams,
                onChanged: (_) => onChanged?.call(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Wrap of selectable chips for a small enum.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });
  final List<T> values;
  final T? selected;
  final String Function(T v) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final v in values)
        ChoiceChip(
          label: Text(label(v)),
          selected: v == selected,
          showCheckmark: false,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: v == selected ? context.palette.onAccent : context.palette.text,
          ),
          onSelected: (_) => onSelected(v),
        ),
    ],
  );
}
