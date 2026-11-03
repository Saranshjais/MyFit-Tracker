import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../nutrition_models.dart';
import '../nutrition_providers.dart';

/// Compact nutrient summary used in sheets and editors.
class NutrientSummary extends StatelessWidget {
  const NutrientSummary({super.key, required this.nutrients, this.title});
  final Nutrients nutrients;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    Widget cell(String label, String value, Color color) => Expanded(
      child: Column(
        children: [
          Text(value, style: t.titleMedium?.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, style: t.bodySmall),
        ],
      ),
    );
    return AppCard(
      color: p.backgroundAlt,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          if (title != null) ...[Text(title!, style: t.labelMedium), const SizedBox(height: 8)],
          Row(
            children: [
              cell('kcal', formatThousands(nutrients.calories), p.text),
              cell('Protein', formatGrams(nutrients.protein), p.protein),
              cell('Carbs', formatGrams(nutrients.carbs), p.carbs),
              cell('Fat', formatGrams(nutrients.fat), p.fat),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nutrients.fiber == null
                ? 'Fibre: no data'
                : 'Fibre ${formatGrams(nutrients.fiber!)}${nutrients.fiberMissing > 0 ? ' (incomplete: ${nutrients.fiberMissing} without data)' : ''}',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}

typedef PortionChoice = ({FoodPortion portion, String category});

/// Choose how much of [food] and (optionally) which meal it belongs to.
Future<PortionChoice?> showFoodAmountSheet(
  BuildContext context, {
  required FoodItem food,
  String? category,
  bool askCategory = true,
  FoodPortion? initial,
  String confirmLabel = 'Add',
}) => showModalBottomSheet<PortionChoice>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _FoodAmountSheet(
    food: food,
    category: category,
    askCategory: askCategory,
    initial: initial,
    confirmLabel: confirmLabel,
  ),
);

class _FoodAmountSheet extends ConsumerStatefulWidget {
  const _FoodAmountSheet({
    required this.food,
    this.category,
    required this.askCategory,
    this.initial,
    required this.confirmLabel,
  });
  final FoodItem food;
  final String? category;
  final bool askCategory;
  final FoodPortion? initial;
  final String confirmLabel;

  @override
  ConsumerState<_FoodAmountSheet> createState() => _FoodAmountSheetState();
}

class _FoodAmountSheetState extends ConsumerState<_FoodAmountSheet> {
  late FoodServing? _serving = widget.initial == null ? widget.food.defaultServing : widget.initial!.serving;
  late final _amount = TextEditingController(
    text: formatNumber(widget.initial?.count ?? (widget.food.defaultServing == null ? 100 : 1), decimals: 2),
  );
  String? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _count {
    final v = parseDecimal(_amount.text);
    return v == null || v <= 0 ? null : v;
  }

  void _step(int dir) {
    final step = _serving == null ? 10.0 : 0.5;
    final next = ((_count ?? 0) + dir * step).clamp(step, 100000.0);
    setState(() => _amount.text = formatNumber(next, decimals: 2));
  }

  void _selectServing(FoodServing? s) {
    if (s?.label == _serving?.label) return;
    // Keep the same total amount when switching between servings and grams.
    final base = _count == null ? null : (_serving == null ? _count! : _count! * _serving!.quantity);
    setState(() {
      _serving = s;
      if (base != null) _amount.text = formatNumber(s == null ? base : base / s.quantity, decimals: 2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final food = widget.food;
    final count = _count;
    final portion = count == null ? null : FoodPortion(food: food, serving: _serving, count: count);
    final categories = ref.watch(mealCategoriesProvider).value ?? const <String>[];
    final category = _category ?? (categories.isEmpty ? null : suggestedMealCategory(DateTime.now(), categories));
    final unitWord = food.baseUnit == 'ml' ? 'Millilitres (ml)' : 'Grams (g)';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(food.name, style: t.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${food.preparationState.label} · per 100 ${food.baseUnit}: ${formatThousands(food.per.calories)} kcal, '
                '${formatGrams(food.per.protein)} protein',
                style: t.bodySmall,
              ),
              if (food.isEstimate)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Values are estimates. ${food.source}', style: t.bodySmall?.copyWith(color: p.warning)),
                ),
              const SizedBox(height: 14),
              Text('Serving', style: t.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in food.servings)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _serving?.label == s.label,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _serving?.label == s.label ? p.onAccent : p.text,
                      ),
                      onSelected: (_) => _selectServing(s),
                    ),
                  ChoiceChip(
                    label: Text(unitWord),
                    selected: _serving == null,
                    showCheckmark: false,
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, color: _serving == null ? p.onAccent : p.text),
                    onSelected: (_) => _selectServing(null),
                  ),
                ],
              ),
              if (_serving != null && _serving!.isEstimate)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Household serving sizes are estimates. Weigh food for better accuracy.',
                    style: t.bodySmall,
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton.outlined(tooltip: 'Less', onPressed: () => _step(-1), icon: const Icon(Icons.remove)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      onChanged: (_) => setState(() {}),
                      style: t.titleLarge,
                      decoration: InputDecoration(
                        suffixText: _serving == null ? food.baseUnit : (count == 1 ? 'serving' : 'servings'),
                        errorText: count == null ? 'Enter an amount above 0' : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(tooltip: 'More', onPressed: () => _step(1), icon: const Icon(Icons.add)),
                ],
              ),
              if (portion != null && _serving != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '= ${formatNumber(portion.baseQuantity)} ${food.baseUnit}',
                    style: t.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 12),
              NutrientSummary(nutrients: portion?.nutrients ?? Nutrients.zero),
              if (widget.askCategory && categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                LabeledDropdown<String>(
                  label: 'Meal',
                  value: category,
                  items: {...categories, ?category}.toList(),
                  onChanged: (v) => setState(() => _category = v),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: portion == null
                    ? null
                    : () => Navigator.pop<PortionChoice>(context, (
                        portion: portion,
                        category: category ?? 'Other Snacks',
                      )),
                child: Text(widget.confirmLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Log a saved meal with a number of servings.
Future<({double servings, String category})?> showMealServingsSheet(
  BuildContext context, {
  required SavedMeal meal,
  String? category,
}) => showModalBottomSheet<({double servings, String category})>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _MealServingsSheet(meal: meal, category: category),
);

class _MealServingsSheet extends ConsumerStatefulWidget {
  const _MealServingsSheet({required this.meal, this.category});
  final SavedMeal meal;
  final String? category;

  @override
  ConsumerState<_MealServingsSheet> createState() => _MealServingsSheetState();
}

class _MealServingsSheetState extends ConsumerState<_MealServingsSheet> {
  double _servings = 1;
  late String? _category = widget.category ?? widget.meal.category;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final categories = ref.watch(mealCategoriesProvider).value ?? const <String>[];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.meal.name, style: t.titleLarge),
            const SizedBox(height: 4),
            Text(widget.meal.summary, style: t.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('Servings', style: t.titleSmall)),
                IconButton.outlined(
                  tooltip: 'Fewer',
                  onPressed: _servings > 0.5 ? () => setState(() => _servings -= 0.5) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 56,
                  child: Text(formatNumber(_servings), textAlign: TextAlign.center, style: t.titleLarge),
                ),
                IconButton.outlined(
                  tooltip: 'More',
                  onPressed: _servings < 20 ? () => setState(() => _servings += 0.5) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            NutrientSummary(nutrients: widget.meal.nutrients.scale(_servings)),
            const SizedBox(height: 12),
            if (categories.isNotEmpty)
              LabeledDropdown<String>(
                label: 'Meal',
                value: _category,
                items: {...categories, ?_category}.toList(),
                onChanged: (v) => setState(() => _category = v),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, (servings: _servings, category: _category ?? widget.meal.category)),
              child: const Text('Log meal'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Change the amount or meal of a diary entry, or delete it. The entry's
/// stored values are scaled; the food database is not consulted.
Future<void> showEditFoodLogSheet(BuildContext context, FoodLog log) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _EditFoodLogSheet(log: log),
);

class _EditFoodLogSheet extends ConsumerStatefulWidget {
  const _EditFoodLogSheet({required this.log});
  final FoodLog log;

  @override
  ConsumerState<_EditFoodLogSheet> createState() => _EditFoodLogSheetState();
}

class _EditFoodLogSheetState extends ConsumerState<_EditFoodLogSheet> {
  late final _qty = TextEditingController(text: formatNumber(widget.log.quantity, decimals: 2));
  late String _category = widget.log.mealCategory;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final q = parseDecimal(_qty.text);
    if (q == null || q <= 0) return;
    final repo = ref.read(foodLogRepositoryProvider);
    final ok = await runGuarded(context, () async {
      if ((q - widget.log.quantity).abs() > 1e-9) await repo.updateQuantity(widget.log.id, q);
      if (_category != widget.log.mealCategory) await repo.updateCategory(widget.log.id, _category);
      ref.read(nutritionRevisionProvider.notifier).bump();
    });
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete entry?',
      message: '"${widget.log.displayName}" will be removed from this day.',
      confirm: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(foodLogRepositoryProvider).delete(widget.log.id);
    ref.read(nutritionRevisionProvider.notifier).bump();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final log = widget.log;
    final q = parseDecimal(_qty.text);
    final valid = q != null && q > 0;
    final scaled = valid ? log.nutrients.scale(q / log.quantity) : log.nutrients;
    final categories = ref.watch(mealCategoriesProvider).value ?? const <String>[];
    final suffix = log.sourceType == FoodLogSource.meal
        ? 'servings'
        : (log.isBaseUnit ? log.unit : '× ${log.unit.replaceFirst(RegExp(r'^1\s+'), '')}');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(log.displayName, style: t.titleLarge),
              const SizedBox(height: 4),
              Text('Logged with the values at the time. Editing the amount scales them.', style: t.bodySmall),
              const SizedBox(height: 16),
              TextField(
                controller: _qty,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  suffixText: suffix,
                  errorText: valid ? null : 'Enter an amount above 0',
                ),
              ),
              const SizedBox(height: 12),
              NutrientSummary(nutrients: scaled),
              if (log.ingredients.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Ingredients (per serving, as logged)', style: t.titleSmall),
                const SizedBox(height: 4),
                for (final i in log.ingredients)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text('${i.name} · ${i.quantityLabel}', style: t.bodySmall)),
                        Text('${formatThousands(i.nutrients.calories)} kcal', style: t.bodySmall),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              if (categories.isNotEmpty)
                LabeledDropdown<String>(
                  label: 'Meal',
                  value: _category,
                  items: {...categories, _category}.toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _delete,
                    style: OutlinedButton.styleFrom(foregroundColor: p.error),
                    child: const Text('Delete'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(onPressed: valid ? _save : null, child: const Text('Save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
