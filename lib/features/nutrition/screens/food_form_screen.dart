import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../nutrition_models.dart';
import '../nutrition_providers.dart';

class _ServingRow {
  _ServingRow({String label = '', String quantity = '', this.isEstimate = true})
    : label = TextEditingController(text: label),
      quantity = TextEditingController(text: quantity);
  final TextEditingController label;
  final TextEditingController quantity;
  bool isEstimate;

  void dispose() {
    label.dispose();
    quantity.dispose();
  }
}

/// Create a custom food or correct an existing one. Pops with the food id.
class FoodFormScreen extends ConsumerStatefulWidget {
  const FoodFormScreen({super.key, this.foodId});
  final int? foodId;

  @override
  ConsumerState<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends ConsumerState<FoodFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _source = TextEditingController(text: 'My own entry');
  String _category = 'Other';
  String _unit = 'g';
  PreparationState _state = PreparationState.asEaten;
  bool _isEstimate = true;
  final List<_ServingRow> _servings = [];
  FoodItem? _original;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.foodId != null) {
      final f = await ref.read(foodRepositoryProvider).byId(widget.foodId!);
      if (f != null) {
        _original = f;
        _name.text = f.name;
        _category = f.category;
        _unit = f.baseUnit;
        _state = f.preparationState;
        _isEstimate = f.isEstimate;
        _source.text = f.source;
        // Values are edited per 100 g/ml.
        final per100 = f.per.scale(100 / f.baseQuantity);
        _kcal.text = formatNumber(per100.calories, decimals: 1);
        _protein.text = formatNumber(per100.protein, decimals: 1);
        _carbs.text = formatNumber(per100.carbs, decimals: 1);
        _fat.text = formatNumber(per100.fat, decimals: 1);
        _fiber.text = per100.fiber == null ? '' : formatNumber(per100.fiber!, decimals: 1);
        for (final s in f.servings) {
          _servings.add(
            _ServingRow(label: s.label, quantity: formatNumber(s.quantity, decimals: 1), isEstimate: s.isEstimate),
          );
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _carbs, _fat, _fiber, _source]) {
      c.dispose();
    }
    for (final s in _servings) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final fiber = parseDecimal(_fiber.text);
    final food = FoodItem(
      id: _original?.id ?? 0,
      name: _name.text,
      category: _category,
      baseUnit: _unit,
      baseQuantity: 100,
      per: Nutrients(
        calories: parseDecimal(_kcal.text)!,
        protein: parseDecimal(_protein.text)!,
        carbs: parseDecimal(_carbs.text)!,
        fat: parseDecimal(_fat.text)!,
        fiber: fiber,
        fiberMissing: fiber == null ? 1 : 0,
      ),
      preparationState: _state,
      source: _source.text.trim().isEmpty ? 'My own entry' : _source.text,
      isEstimate: _isEstimate,
      isCustom: _original?.isCustom ?? true,
      servings: [
        for (final s in _servings)
          if (s.label.text.trim().isNotEmpty && (parseDecimal(s.quantity.text) ?? 0) > 0)
            FoodServing(
              label: s.label.text.trim(),
              quantity: parseDecimal(s.quantity.text)!,
              isEstimate: s.isEstimate,
              isCustom: true,
            ),
      ],
    );
    int? id;
    final ok = await runGuarded(context, () async {
      final repo = ref.read(foodRepositoryProvider);
      if (_original == null) {
        id = await repo.create(food);
      } else {
        await repo.update(food);
        id = food.id;
      }
      ref.read(nutritionRevisionProvider.notifier).bump();
    });
    if (ok && mounted) context.pop<int>(id);
  }

  Future<void> _delete() async {
    final f = _original!;
    final ok = await showConfirmDialog(
      context,
      title: 'Delete "${f.name}"?',
      message:
          'Past diary entries keep their values. If a saved meal uses this food it will be hidden instead of deleted.',
      confirm: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    final archived = await ref.read(foodRepositoryProvider).deleteOrArchive(f.id);
    ref.read(nutritionRevisionProvider.notifier).bump();
    if (!mounted) return;
    showSnack(context, archived ? 'Hidden from search; saved meals still use it.' : 'Food deleted.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    String? required(String? v) => validateRequiredNumber(v, min: 0, max: 100, label: 'Value');
    return Scaffold(
      appBar: AppBar(
        title: Text(_original == null ? 'Custom food' : 'Edit food'),
        actions: [
          if (_original != null)
            IconButton(tooltip: 'Delete food', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
          TextButton(onPressed: _loading ? null : _save, child: const Text('Save')),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : Form(
              key: _form,
              child: ListView(
                padding: pagePadding,
                children: [
                  if (_original != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Corrections apply to future entries only. Days already logged keep the values they were logged with.',
                        style: t.bodySmall?.copyWith(color: p.warning),
                      ),
                    ),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'Food name', counterText: ''),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                  LabeledDropdown<String>(
                    label: 'Category',
                    value: _category,
                    items: {...foodCategories, _category}.toList(),
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LabeledDropdown<String>(
                          label: 'Measured in',
                          value: _unit,
                          items: const ['g', 'ml'],
                          itemLabel: (u) => u == 'g' ? 'Grams' : 'Millilitres',
                          onChanged: (v) => setState(() => _unit = v ?? _unit),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LabeledDropdown<PreparationState>(
                          label: 'State',
                          value: _state,
                          items: PreparationState.values,
                          itemLabel: (s) => s.label,
                          onChanged: (v) => setState(() => _state = v ?? _state),
                        ),
                      ),
                    ],
                  ),
                  SectionTitle('Nutrition per 100 $_unit'),
                  DecimalField(
                    controller: _kcal,
                    label: 'Calories',
                    suffix: 'kcal',
                    validator: (v) => validateRequiredNumber(v, min: 0, max: 900, label: 'Calories'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DecimalField(controller: _protein, label: 'Protein', suffix: 'g', validator: required),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DecimalField(controller: _carbs, label: 'Carbs', suffix: 'g', validator: required),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DecimalField(controller: _fat, label: 'Fat', suffix: 'g', validator: required),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DecimalField(
                    controller: _fiber,
                    label: 'Fibre (optional)',
                    suffix: 'g',
                    helper: 'Leave empty if unknown. It will show as "no data", not zero.',
                    validator: (v) => validateOptionalNumber(v, min: 0, max: 100, label: 'Fibre'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _source,
                    maxLength: 140,
                    decoration: const InputDecoration(
                      labelText: 'Source',
                      helperText: 'e.g. package label, USDA, own recipe',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Values are estimates'),
                    subtitle: const Text('Turn off only for values from a reliable label or reference table.'),
                    value: _isEstimate,
                    onChanged: (v) => setState(() => _isEstimate = v),
                  ),
                  const SectionTitle('Servings'),
                  Text('Define household servings, e.g. "1 bowl (150 g)". Amount is in $_unit.', style: t.bodySmall),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _servings.length; i++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _servings[i].label,
                            decoration: const InputDecoration(labelText: 'Serving name'),
                            validator: (v) => (v ?? '').trim().isEmpty && _servings[i].quantity.text.trim().isNotEmpty
                                ? 'Name it'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DecimalField(
                            controller: _servings[i].quantity,
                            label: 'Amount',
                            suffix: _unit,
                            validator: (v) => _servings[i].label.text.trim().isEmpty
                                ? null
                                : validateRequiredNumber(v, min: 0, max: 5000, allowZero: false, label: 'Amount'),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove serving',
                          onPressed: () => setState(() => _servings.removeAt(i).dispose()),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _servings.add(_ServingRow())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add serving'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
