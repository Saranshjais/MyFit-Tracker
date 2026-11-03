import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../food_visuals.dart';
import '../nutrition_models.dart';
import '../nutrition_providers.dart';
import 'food_sheets.dart';

/// Search the food database and log foods or saved meals. With [pickOnly]
/// it returns the chosen [FoodPortion] to the caller instead of logging.
class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({super.key, this.date, this.category, this.pickOnly = false});
  final String? date;
  final String? category;
  final bool pickOnly;

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  final _search = TextEditingController();
  int _tab = 0;
  String? _categoryFilter;
  late String? _meal = widget.category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _date => widget.date ?? dateKey(ref.read(todayProvider));

  Future<void> _chooseFood(FoodItem food) async {
    final choice = await showFoodAmountSheet(
      context,
      food: food,
      category: _meal,
      askCategory: !widget.pickOnly,
      confirmLabel: widget.pickOnly ? 'Add to meal' : 'Add',
    );
    if (choice == null || !mounted) return;
    if (widget.pickOnly) {
      context.pop<FoodPortion>(choice.portion);
      return;
    }
    _meal = choice.category;
    final repo = ref.read(foodLogRepositoryProvider);
    final id = await repo.logFood(date: _date, category: choice.category, portion: choice.portion);
    ref.read(nutritionRevisionProvider.notifier).bump();
    if (!mounted) return;
    showSnack(
      context,
      'Added ${food.name} to ${choice.category} (${formatKcal(choice.portion.nutrients.calories)})',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await repo.delete(id);
          ref.read(nutritionRevisionProvider.notifier).bump();
        },
      ),
    );
  }

  Future<void> _logMeal(SavedMeal meal) async {
    final choice = await showMealServingsSheet(context, meal: meal, category: _meal);
    if (choice == null || !mounted) return;
    await runGuarded(context, () async {
      await ref
          .read(foodLogRepositoryProvider)
          .logMeal(
            date: _date,
            category: choice.category,
            name: meal.name,
            items: meal.items.map((i) => i.portion).toList(),
            servings: choice.servings,
            savedMealId: meal.id,
          );
      ref.read(nutritionRevisionProvider.notifier).bump();
    }, success: 'Logged ${meal.name} to ${choice.category}');
  }

  Future<void> _createFood() async {
    final id = await context.push<int>('/diet/foods/new');
    if (id == null || !mounted) return;
    final food = await ref.read(foodRepositoryProvider).byId(id);
    if (food != null && mounted) await _chooseFood(food);
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final tabs = widget.pickOnly ? const ['Search', 'Recent'] : const ['Search', 'Recent', 'My Meals'];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickOnly ? 'Choose food' : 'Add Food'),
        actions: [
          if (!widget.pickOnly)
            IconButton(
              tooltip: 'Speak or type a meal',
              icon: const Icon(Icons.mic),
              onPressed: () =>
                  context.push(Uri(path: '/diet/quick', queryParameters: {'date': _date, 'meal': ?_meal}).toString()),
            ),
        ],
        bottom: widget.pickOnly || widget.date == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Logging to ${relativeDayLabel(parseDateKey(widget.date!), today)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: PillTabs(labels: tabs, selected: _tab, onChanged: (i) => setState(() => _tab = i)),
          ),
          Expanded(
            child: switch (_tab) {
              0 => _searchTab(),
              1 => _recentTab(),
              _ => _mealsTab(),
            },
          ),
        ],
      ),
    );
  }

  Widget _createButton() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: OutlinedButton.icon(
      onPressed: _createFood,
      icon: const Icon(Icons.add),
      label: const Text('Create a custom food'),
    ),
  );

  Widget _searchTab() {
    final p = context.palette;
    final categories = ref.watch(foodCategoriesProvider).value ?? const <String>[];
    final results = ref.watch(foodSearchProvider((query: _search.text, category: _categoryFilter)));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search food (e.g. roti, dal, paneer…)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final c in [null, ...categories])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: c == null
                        ? null
                        : Icon(
                            foodCategoryIcon(c),
                            size: 16,
                            color: _categoryFilter == c ? p.onAccent : p.textSecondary,
                          ),
                    label: Text(c ?? 'All'),
                    selected: _categoryFilter == c,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _categoryFilter == c ? p.onAccent : p.text,
                    ),
                    onSelected: (_) => setState(() => _categoryFilter = c),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView(
            value: results,
            builder: (foods) => ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: foods.length + 1,
              itemBuilder: (context, i) {
                if (i == foods.length) {
                  return Column(
                    children: [
                      if (foods.isEmpty)
                        const EmptyState(
                          icon: Icons.search_off,
                          title: 'No foods found',
                          message: 'Check the spelling or add it as a custom food.',
                          compact: true,
                        ),
                      _createButton(),
                    ],
                  );
                }
                return FoodRow(food: foods[i], onTap: () => _chooseFood(foods[i]));
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _recentTab() {
    final recent = ref.watch(recentFoodsProvider);
    return AsyncView(
      value: recent,
      builder: (foods) {
        if (foods.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            title: 'No recent foods',
            message: 'Foods you log appear here for quick repeats.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [for (final f in foods) FoodRow(food: f, onTap: () => _chooseFood(f))],
        );
      },
    );
  }

  Widget _mealsTab() {
    final meals = ref.watch(savedMealsProvider);
    final t = Theme.of(context).textTheme;
    return AsyncView(
      value: meals,
      builder: (meals) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (meals.isEmpty)
            const EmptyState(
              icon: Icons.restaurant_menu,
              title: 'No saved meals',
              message: 'Save meals you eat often to log them in one tap.',
              compact: true,
            ),
          for (final m in meals)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => _logMeal(m),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    IconTile(icon: mealCategoryIcon(m.category), color: context.palette.fat, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name, style: t.titleSmall),
                          Text(m.summary, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            '${formatKcal(m.nutrients.calories)} · ${formatGrams(m.nutrients.protein)} protein',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.add_circle_outline, color: context.palette.accentText),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () =>
                context.push(Uri(path: '/diet/meal/new', queryParameters: {'date': _date, 'meal': ?_meal}).toString()),
            icon: const Icon(Icons.add),
            label: const Text('Create a meal'),
          ),
        ],
      ),
    );
  }
}

/// Food list row: name, default serving, calories and protein.
class FoodRow extends StatelessWidget {
  const FoodRow({super.key, required this.food, required this.onTap, this.showSource = false});
  final FoodItem food;
  final VoidCallback onTap;
  final bool showSource;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final serving = food.defaultServing;
    final n = serving == null ? food.per : nutrientsFor(food, serving.quantity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            FoodThumb(category: food.category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.name, style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text(serving?.label ?? '100 ${food.baseUnit}', style: t.bodySmall),
                  Text(
                    '${formatKcal(n.calories)} · ${formatGrams(n.protein)} protein',
                    style: t.bodySmall?.copyWith(color: p.text),
                  ),
                  if (showSource) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (food.isCustom) const Badge2('Custom'),
                        Badge2(
                          food.isEstimate ? 'Estimate' : 'Reference',
                          color: food.isEstimate ? p.warning : p.accentText,
                        ),
                        Badge2(food.preparationState.label),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.add_circle, color: p.accentText, size: 28),
          ],
        ),
      ),
    );
  }
}
