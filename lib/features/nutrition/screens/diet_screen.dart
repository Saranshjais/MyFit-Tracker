import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../profile/user_profile.dart';
import '../../settings/app_settings.dart';
import '../../water/water_repository.dart';
import '../../water/water_sheet.dart';
import '../food_visuals.dart';
import '../nutrition_models.dart';
import '../nutrition_providers.dart';
import 'food_sheets.dart';

class DietScreen extends ConsumerStatefulWidget {
  const DietScreen({super.key});

  @override
  ConsumerState<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends ConsumerState<DietScreen> {
  DateTime? _date;

  String _addFoodLocation(String date, String meal) =>
      Uri(path: '/diet/add', queryParameters: {'date': date, 'meal': meal}).toString();

  Future<void> _manageCategories() async {
    final categories = await ref.read(mealCategoriesProvider.future);
    if (!mounted) return;
    final choice = await showChoiceSheet<String>(
      context,
      title: 'Meal categories',
      options: [
        (value: '__add', label: 'Add a category', subtitle: 'e.g. Pre-workout, Late night', icon: Icons.add),
        for (final c in categories.where((c) => !AppDatabase.defaultMealCategories.contains(c)))
          (value: c, label: c, subtitle: 'Tap to remove', icon: Icons.delete_outline),
      ],
    );
    if (choice == null || !mounted) return;
    final repo = ref.read(foodLogRepositoryProvider);
    if (choice == '__add') {
      final name = await showTextInputDialog(
        context,
        title: 'New meal category',
        label: 'Name',
        confirm: 'Add',
        maxLength: 30,
      );
      if (name == null) return;
      await repo.addMealCategory(name);
    } else {
      await repo.deleteMealCategory(choice);
      if (mounted) showSnack(context, 'Removed "$choice". Entries already logged under it keep their label.');
    }
    ref.read(nutritionRevisionProvider.notifier).bump();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final date = _date ?? today;
    final key = dateKey(date);
    final profile = ref.watch(profileProvider);
    final logsAsync = ref.watch(foodLogsForDateProvider(key));
    final logs = logsAsync.value ?? const <FoodLog>[];
    final categories = ref.watch(mealCategoriesProvider).value ?? const <String>[];
    final totals = Nutrients.sum(logs.map((l) => l.nutrients));
    final cal = TargetProgress(totals.calories, profile.calorieTarget);
    final allCategories = [
      ...categories,
      ...logs.map((l) => l.mealCategory).where((c) => !categories.contains(c)).toSet(),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: pagePadding,
          children: [
            ScreenHeader(
              title: 'Diet / Nutrition',
              trailing: PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (v) {
                  if (v == 'meals') context.go('/diet/meals');
                  if (v == 'foods') context.go('/diet/foods');
                  if (v == 'categories') _manageCategories();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'meals', child: Text('My meals')),
                  PopupMenuItem(value: 'foods', child: Text('Food database')),
                  PopupMenuItem(value: 'categories', child: Text('Meal categories')),
                ],
              ),
            ),
            DateNavigator(
              date: date,
              today: today,
              onChanged: (d) => setState(() => _date = isSameDay(d, today) ? null : d),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ProgressRing(
                    fraction: cal.fraction,
                    over: cal.isOver,
                    size: 150,
                    stroke: 11,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatThousands(totals.calories), style: t.headlineMedium),
                        Text(
                          cal.hasTarget ? '/ ${formatThousands(cal.target!)} kcal' : 'kcal eaten',
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (cal.hasTarget)
                    Text(
                      cal.isOver ? '${formatKcal(cal.excess!)} over target' : '${formatKcal(cal.remaining!)} remaining',
                      style: t.titleSmall?.copyWith(color: cal.isOver ? p.warning : p.accentText),
                    )
                  else
                    TextButton(onPressed: () => context.go('/more/profile'), child: const Text('Set daily targets')),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MacroRing(
                          label: 'Protein',
                          consumed: totals.protein,
                          target: profile.proteinTarget,
                          color: p.protein,
                        ),
                      ),
                      Expanded(
                        child: _MacroRing(
                          label: 'Carbs',
                          consumed: totals.carbs,
                          target: profile.carbsTarget,
                          color: p.carbs,
                        ),
                      ),
                      Expanded(
                        child: _MacroRing(label: 'Fat', consumed: totals.fat, target: profile.fatTarget, color: p.fat),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    totals.fiber == null
                        ? (logs.isEmpty
                              ? 'Totals are calculated from the entries you log.'
                              : 'Fibre: no data for these foods')
                        : 'Fibre ${formatGrams(totals.fiber!)}'
                              '${totals.fiberMissing > 0 ? ' · ${totals.fiberMissing} ${totals.fiberMissing == 1 ? 'entry has' : 'entries have'} no fibre data' : ''}',
                    style: t.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SectionTitle('Meals'),
            if (logsAsync.hasError) ErrorView(error: logsAsync.error!),
            for (final c in allCategories) ...[
              _MealCard(
                category: c,
                logs: logs.where((l) => l.mealCategory == c).toList(),
                onAdd: () => context.go(_addFoodLocation(key, c)),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            _WaterCard(date: key),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go(
                Uri(
                  path: '/diet/meal/new',
                  queryParameters: {'date': key, 'meal': suggestedMealCategory(DateTime.now(), categories)},
                ).toString(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Meal'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go(_addFoodLocation(key, suggestedMealCategory(DateTime.now(), categories))),
              icon: const Icon(Icons.search),
              label: const Text('Add a single food'),
            ),
            const SizedBox(height: 12),
            Text(
              'Nutrition values are estimates from reference tables and typical recipes. Totals are approximate.',
              style: t.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRing extends StatelessWidget {
  const _MacroRing({required this.label, required this.consumed, required this.target, required this.color});
  final String label;
  final double consumed;
  final double? target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final progress = TargetProgress(consumed, target);
    return Column(
      children: [
        ProgressRing(fraction: progress.fraction, over: progress.isOver, size: 58, stroke: 6, color: color),
        const SizedBox(height: 6),
        Text(label, style: t.labelLarge),
        Text(
          progress.hasTarget ? '${consumed.round()} / ${target!.round()} g' : '${consumed.round()} g',
          style: t.bodySmall,
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.category, required this.logs, required this.onAdd});
  final String category;
  final List<FoodLog> logs;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final total = Nutrients.sum(logs.map((l) => l.nutrients));
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(icon: mealCategoryIcon(category), color: p.fat, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category, style: t.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      logs.isEmpty ? 'Nothing logged' : logs.map((l) => l.displayName).join(' + '),
                      style: t.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (logs.isNotEmpty)
                      Text(
                        '${formatKcal(total.calories)} · ${formatGrams(total.protein)} protein',
                        style: t.bodySmall?.copyWith(color: p.text, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Add food to $category',
                onPressed: onAdd,
                icon: Icon(Icons.add_circle, color: p.accentText, size: 30),
              ),
            ],
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Divider(color: p.border, height: 1),
            for (final l in logs)
              InkWell(
                onTap: () => showEditFoodLogSheet(context, l),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 9, 10, 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.displayName, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text(l.quantityLabel, style: t.bodySmall),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatKcal(l.nutrients.calories), style: t.bodyMedium),
                          Text('${formatGrams(l.nutrients.protein)} P', style: t.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _WaterCard extends ConsumerWidget {
  const _WaterCard({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);
    final target = ref.watch(profileProvider.select((x) => x.waterTargetMl));
    final logs = ref.watch(waterForDateProvider(date)).value ?? const <WaterLog>[];
    final total = logs.fold<double>(0, (s, l) => s + l.ml);
    return AppCard(
      onTap: () => showWaterSheet(context, date: date),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          IconTile(icon: Icons.water_drop, color: p.water, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Water', style: t.titleSmall),
                const SizedBox(height: 2),
                Text(
                  target == null
                      ? formatWater(total, settings.waterUnit)
                      : '${formatWater(total, settings.waterUnit)} of ${formatWater(target, settings.waterUnit)}',
                  style: t.bodySmall,
                ),
                if (target != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(value: (total / target).clamp(0, 1), minHeight: 4, color: p.water),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Add a glass of water',
            onPressed: () async {
              await ref.read(waterRepositoryProvider).add(date, settings.glassSizeMl);
              ref.read(nutritionRevisionProvider.notifier).bump();
              if (context.mounted) showSnack(context, 'Added ${formatWater(settings.glassSizeMl, settings.waterUnit)}');
            },
            icon: Icon(Icons.add_circle, color: p.water, size: 30),
          ),
        ],
      ),
    );
  }
}
