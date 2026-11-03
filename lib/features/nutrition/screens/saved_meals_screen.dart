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
import '../food_visuals.dart';
import '../nutrition_models.dart';
import '../nutrition_providers.dart';
import 'food_sheets.dart';

class SavedMealsScreen extends ConsumerWidget {
  const SavedMealsScreen({super.key});

  Future<void> _menu(BuildContext context, WidgetRef ref, SavedMeal meal, String action) async {
    final repo = ref.read(mealRepositoryProvider);
    void bump() => ref.read(nutritionRevisionProvider.notifier).bump();
    switch (action) {
      case 'log':
        final choice = await showMealServingsSheet(context, meal: meal);
        if (choice == null || !context.mounted) return;
        await runGuarded(context, () async {
          await ref
              .read(foodLogRepositoryProvider)
              .logMeal(
                date: dateKey(ref.read(todayProvider)),
                category: choice.category,
                name: meal.name,
                items: meal.items.map((i) => i.portion).toList(),
                servings: choice.servings,
                savedMealId: meal.id,
              );
          bump();
        }, success: 'Logged ${meal.name} today');
      case 'duplicate':
        await repo.duplicate(meal.id!);
        bump();
      case 'delete':
        final ok = await showConfirmDialog(
          context,
          title: 'Delete "${meal.name}"?',
          message: 'The saved meal is removed. Days you already logged it on keep their entries.',
          confirm: 'Delete',
          destructive: true,
        );
        if (!ok) return;
        await repo.delete(meal.id!);
        bump();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(savedMealsProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('My meals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/diet/meal/new'),
        icon: const Icon(Icons.add),
        label: const Text('New meal'),
      ),
      body: AsyncView(
        value: meals,
        builder: (meals) {
          if (meals.isEmpty) {
            return EmptyState(
              icon: Icons.restaurant_menu,
              title: 'No saved meals yet',
              message: 'Save meals or recipes you eat often, then log them in one tap.',
              action: 'Create a meal',
              onAction: () => context.push('/diet/meal/new'),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              for (final m in meals) ...[
                AppCard(
                  onTap: () => context.push('/diet/meal/${m.id}'),
                  padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                  child: Row(
                    children: [
                      IconTile(icon: mealCategoryIcon(m.category), color: context.palette.fat, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: t.titleSmall),
                            Text('${m.category} · ${m.items.length} items', style: t.bodySmall),
                            Text(
                              '${formatKcal(m.nutrients.calories)} · ${formatGrams(m.nutrients.protein)} protein',
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (a) => _menu(context, ref, m, a),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'log', child: Text('Log today')),
                          PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}
