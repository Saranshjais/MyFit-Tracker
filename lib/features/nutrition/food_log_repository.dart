import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/dates.dart';
import 'nutrition_models.dart';

class FoodLogRepository {
  FoodLogRepository(this._db);
  final AppDatabase _db;
  Database get _d => _db.db;

  Future<List<FoodLog>> forDate(String date) async {
    final rows = await _d.query('food_logs', where: 'date = ?', whereArgs: [date], orderBy: 'logged_at, id');
    return rows.map(FoodLog.fromMap).toList();
  }

  Map<String, Object?> _nutrientColumns(Nutrients n) => {
    'calories': n.calories,
    'protein': n.protein,
    'carbohydrates': n.carbs,
    'fat': n.fat,
    'fiber': n.fiber,
    'fiber_missing': n.fiberMissing,
  };

  Future<int> logFood({required String date, required String category, required FoodPortion portion}) {
    if (portion.count <= 0) throw ArgumentError('Quantity must be greater than 0');
    return _d.insert('food_logs', {
      'date': date,
      'meal_category': category,
      'logged_at': timestampNow(),
      'source_type': 'food',
      'source_id': portion.food.id,
      'display_name': portion.food.name,
      'quantity': portion.count,
      'unit': portion.unitLabel,
      'base_quantity': portion.baseQuantity,
      ..._nutrientColumns(portion.nutrients),
    });
  }

  /// Logs [servings] of a meal. The meal's total is multiplied by the number
  /// of servings exactly once, and each ingredient is snapshotted.
  Future<int> logMeal({
    required String date,
    required String category,
    required String name,
    required List<FoodPortion> items,
    double servings = 1,
    int? savedMealId,
  }) {
    if (servings <= 0) throw ArgumentError('Servings must be greater than 0');
    if (items.isEmpty) throw ArgumentError('A meal needs at least one food');
    final ingredients = [
      for (final p in items)
        IngredientSnapshot(name: p.food.name, quantityLabel: p.quantityLabel, nutrients: p.nutrients),
    ];
    final total = Nutrients.sum(ingredients.map((i) => i.nutrients)).scale(servings);
    return _d.insert('food_logs', {
      'date': date,
      'meal_category': category,
      'logged_at': timestampNow(),
      'source_type': 'meal',
      'source_id': savedMealId,
      'display_name': name.trim().isEmpty ? 'Meal' : name.trim(),
      'quantity': servings,
      'unit': 'serving',
      'base_quantity': null,
      ..._nutrientColumns(total),
      'detail': jsonEncode(ingredients.map((i) => i.toJson()).toList()),
    });
  }

  /// Changes how much was eaten by scaling the stored snapshot, so the
  /// values the entry was logged with stay the reference.
  Future<void> updateQuantity(int id, double newQuantity) async {
    if (newQuantity <= 0) throw ArgumentError('Quantity must be greater than 0');
    final rows = await _d.query('food_logs', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final log = FoodLog.fromMap(rows.first);
    final factor = newQuantity / log.quantity;
    await _d.update(
      'food_logs',
      {
        'quantity': newQuantity,
        'base_quantity': log.baseQuantity == null ? null : log.baseQuantity! * factor,
        ..._nutrientColumns(log.nutrients.scale(factor)),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCategory(int id, String category) =>
      _d.update('food_logs', {'meal_category': category}, where: 'id = ?', whereArgs: [id]);

  Future<void> delete(int id) => _d.delete('food_logs', where: 'id = ?', whereArgs: [id]);

  /// Daily totals for each date in the range that has entries.
  Future<Map<String, Nutrients>> dailyTotals(String from, String to) async {
    final rows = await _d.rawQuery(
      'SELECT date, SUM(calories) AS c, SUM(protein) AS p, SUM(carbohydrates) AS cb, SUM(fat) AS f, '
      'SUM(fiber) AS fb, SUM(fiber_missing) AS fm FROM food_logs WHERE date BETWEEN ? AND ? GROUP BY date',
      [from, to],
    );
    return {
      for (final r in rows)
        r['date'] as String: Nutrients(
          calories: (r['c'] as num).toDouble(),
          protein: (r['p'] as num).toDouble(),
          carbs: (r['cb'] as num).toDouble(),
          fat: (r['f'] as num).toDouble(),
          fiber: (r['fb'] as num?)?.toDouble(),
          fiberMissing: (r['fm'] as num?)?.toInt() ?? 0,
        ),
    };
  }

  // Meal categories ------------------------------------------------------------

  Future<List<String>> mealCategories() async {
    final rows = await _d.query('meal_categories', orderBy: 'sort_order, id');
    return rows.map((r) => r['name'] as String).toList();
  }

  Future<void> addMealCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Enter a name');
    final maxOrder = await _d.rawQuery('SELECT MAX(sort_order) AS m FROM meal_categories');
    await _d.insert('meal_categories', {
      'name': trimmed,
      'sort_order': ((maxOrder.first['m'] as int?) ?? 0) + 1,
      'is_default': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Removes a custom category from the list. Entries already logged under it
  /// keep their label.
  Future<void> deleteMealCategory(String name) =>
      _d.delete('meal_categories', where: 'name = ? AND is_default = 0', whereArgs: [name]);
}
