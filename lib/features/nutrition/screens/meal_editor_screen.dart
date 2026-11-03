import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../food_visuals.dart';
import '../nutrition_models.dart';
import '../nutrition_providers.dart';
import 'food_sheets.dart';

/// Build a meal from foods. Save it as a reusable recipe and/or log it to a
/// day. Editing a saved meal never changes days it was already logged on.
class MealEditorScreen extends ConsumerStatefulWidget {
  const MealEditorScreen({super.key, this.mealId, this.date, this.category});
  final int? mealId;
  final String? date;
  final String? category;

  @override
  ConsumerState<MealEditorScreen> createState() => _MealEditorScreenState();
}

class _MealEditorScreenState extends ConsumerState<MealEditorScreen> {
  final _name = TextEditingController();
  String? _category;
  final List<FoodPortion> _items = [];
  int? _mealId;
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _mealId = widget.mealId;
    _category = widget.category;
    _load();
  }

  Future<void> _load() async {
    if (_mealId != null) {
      final meal = await ref.read(mealRepositoryProvider).byId(_mealId!);
      if (meal != null) {
        _name.text = meal.name;
        _category = meal.category;
        _items.addAll(meal.items.map((i) => i.portion));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _changed() => setState(() => _dirty = true);

  Future<void> _addItem() async {
    final portion = await context.push<FoodPortion>('/diet/pick-food');
    if (portion == null) return;
    _items.add(portion);
    _changed();
  }

  Future<void> _editItem(int index) async {
    final current = _items[index];
    final choice = await showFoodAmountSheet(
      context,
      food: current.food,
      askCategory: false,
      initial: current,
      confirmLabel: 'Update',
    );
    if (choice == null) return;
    _items[index] = choice.portion;
    _changed();
  }

  String? _validate({required bool needName}) {
    if (needName && _name.text.trim().isEmpty) return 'Give the meal a name to save it.';
    if (_items.isEmpty) return 'Add at least one food.';
    return null;
  }

  Future<void> _save() async {
    final problem = _validate(needName: true);
    if (problem != null) {
      showSnack(context, problem);
      return;
    }
    final categories = await ref.read(mealCategoriesProvider.future);
    final meal = SavedMeal(
      id: _mealId,
      name: _name.text,
      category: _category ?? (categories.isEmpty ? 'Lunch' : categories.first),
      items: [for (var i = 0; i < _items.length; i++) SavedMealItem(portion: _items[i], sortOrder: i)],
    );
    if (!mounted) return;
    await runGuarded(context, () async {
      _mealId = await ref.read(mealRepositoryProvider).save(meal);
      ref.read(nutritionRevisionProvider.notifier).bump();
      setState(() => _dirty = false);
    }, success: 'Meal saved');
  }

  Future<void> _logToDay() async {
    final problem = _validate(needName: false);
    if (problem != null) {
      showSnack(context, problem);
      return;
    }
    final date = widget.date ?? dateKey(ref.read(todayProvider));
    final categories = await ref.read(mealCategoriesProvider.future);
    final category = _category ?? suggestedMealCategory(DateTime.now(), categories);
    if (!mounted) return;
    final ok = await runGuarded(context, () async {
      await ref
          .read(foodLogRepositoryProvider)
          .logMeal(
            date: date,
            category: category,
            name: _name.text.trim().isEmpty ? category : _name.text,
            items: List.of(_items),
            savedMealId: _dirty ? null : _mealId,
          );
      ref.read(nutritionRevisionProvider.notifier).bump();
    }, success: 'Added to $category');
    if (ok && mounted) {
      _dirty = false;
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final categories = ref.watch(mealCategoriesProvider).value ?? const <String>[];
    final totals = Nutrients.sum(_items.map((i) => i.nutrients));
    final dayLabel = relativeDayLabel(widget.date == null ? today : parseDateKey(widget.date!), today);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showConfirmDialog(
          context,
          title: 'Discard changes?',
          message: 'Your changes to this meal have not been saved or logged.',
          confirm: 'Discard',
          destructive: true,
        );
        if (leave && context.mounted) {
          setState(() => _dirty = false);
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_mealId == null ? 'Add Meal' : 'Edit Meal'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size(64, 38)),
                child: const Text('Save Meal'),
              ),
            ),
          ],
        ),
        body: _loading
            ? const LoadingView()
            : ListView(
                padding: pagePadding,
                children: [
                  TextField(
                    controller: _name,
                    onChanged: (_) => _changed(),
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 50,
                    decoration: const InputDecoration(
                      labelText: 'Meal name',
                      hintText: 'e.g. Usual lunch',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (categories.isNotEmpty)
                    LabeledDropdown<String>(
                      label: 'Meal category',
                      value: _category,
                      hint: 'Choose',
                      items: {...categories, ?_category}.toList(),
                      onChanged: (v) {
                        _category = v;
                        _changed();
                      },
                    ),
                  const SectionTitle('Food items'),
                  if (_items.isEmpty)
                    const EmptyState(
                      icon: Icons.restaurant,
                      title: 'No foods yet',
                      message: 'Add the foods in this meal and their amounts.',
                      compact: true,
                    ),
                  for (var i = 0; i < _items.length; i++) ...[
                    AppCard(
                      onTap: () => _editItem(i),
                      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                      child: Row(
                        children: [
                          FoodThumb(category: _items[i].food.category),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_items[i].food.name, style: t.titleSmall),
                                Text(_items[i].quantityLabel, style: t.bodySmall),
                                Text(
                                  '${formatKcal(_items[i].nutrients.calories)} · ${formatGrams(_items[i].nutrients.protein)} protein',
                                  style: t.bodySmall?.copyWith(color: p.text),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              _items.removeAt(i);
                              _changed();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: _addItem,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.accentText,
                      side: BorderSide(color: p.accent),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Food Item'),
                  ),
                  const SectionTitle('Meal totals'),
                  NutrientSummary(nutrients: totals),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _logToDay, child: Text('Add to $dayLabel')),
                  const SizedBox(height: 8),
                  Text(
                    'Logging saves a copy of these values with the day, so later edits to this meal or its foods do not change past days.',
                    style: t.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
