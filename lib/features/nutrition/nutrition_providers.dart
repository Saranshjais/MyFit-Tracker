import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/utils/dates.dart';
import 'food_log_repository.dart';
import 'food_repository.dart';
import 'meal_repository.dart';
import 'nutrition_models.dart';

final foodRepositoryProvider = Provider((ref) => FoodRepository(ref.watch(databaseProvider)));
final foodLogRepositoryProvider = Provider((ref) => FoodLogRepository(ref.watch(databaseProvider)));
final mealRepositoryProvider = Provider(
  (ref) => MealRepository(ref.watch(databaseProvider), ref.watch(foodRepositoryProvider)),
);

final foodLogsForDateProvider = FutureProvider.autoDispose.family<List<FoodLog>, String>((ref, date) {
  ref.watch(nutritionRevisionProvider);
  return ref.watch(foodLogRepositoryProvider).forDate(date);
});

/// Totals for a date, summed from that day's saved entries.
final dayTotalsProvider = FutureProvider.autoDispose.family<Nutrients, String>((ref, date) async {
  final logs = await ref.watch(foodLogsForDateProvider(date).future);
  return Nutrients.sum(logs.map((l) => l.nutrients));
});

final mealCategoriesProvider = FutureProvider<List<String>>((ref) {
  ref.watch(nutritionRevisionProvider);
  return ref.watch(foodLogRepositoryProvider).mealCategories();
});

final foodSearchProvider = FutureProvider.autoDispose.family<List<FoodItem>, ({String query, String? category})>((
  ref,
  key,
) {
  ref.watch(nutritionRevisionProvider);
  return ref.watch(foodRepositoryProvider).search(query: key.query, category: key.category);
});

final foodCategoriesProvider = FutureProvider<List<String>>((ref) {
  ref.watch(nutritionRevisionProvider);
  return ref.watch(foodRepositoryProvider).categories();
});

final recentFoodsProvider = FutureProvider.autoDispose<List<FoodItem>>((ref) {
  ref.watch(nutritionRevisionProvider);
  return ref.watch(foodRepositoryProvider).recent();
});

final foodProvider = FutureProvider.autoDispose.family<FoodItem?, int>((ref, id) {
  ref.watch(nutritionRevisionProvider);
  return ref.watch(foodRepositoryProvider).byId(id);
});

final savedMealsProvider = FutureProvider<List<SavedMeal>>((ref) {
  ref.watch(nutritionRevisionProvider);
  return ref.watch(mealRepositoryProvider).all();
});

final savedMealProvider = FutureProvider.autoDispose.family<SavedMeal?, int>((ref, id) {
  ref.watch(nutritionRevisionProvider);
  return ref.watch(mealRepositoryProvider).byId(id);
});

/// Daily totals for the last [days] days ending today, oldest first. Days
/// without entries are absent from the map (not treated as zero intake).
final recentDailyTotalsProvider = FutureProvider.autoDispose.family<Map<String, Nutrients>, int>((ref, days) {
  ref.watch(nutritionRevisionProvider);
  final today = ref.watch(todayProvider);
  return ref.watch(foodLogRepositoryProvider).dailyTotals(dateKey(addDays(today, 1 - days)), dateKey(today));
});

/// Picks the meal category that fits the current time of day.
String suggestedMealCategory(DateTime now, List<String> categories) {
  final h = now.hour;
  final preferred = h < 11
      ? 'Breakfast'
      : h < 16
      ? 'Lunch'
      : h < 19
      ? 'Evening Snack'
      : 'Dinner';
  return categories.contains(preferred) ? preferred : (categories.isEmpty ? preferred : categories.first);
}
