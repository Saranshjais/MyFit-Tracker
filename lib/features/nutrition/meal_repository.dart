import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/dates.dart';
import 'food_repository.dart';
import 'nutrition_models.dart';

class MealRepository {
  MealRepository(this._db, this._foods);
  final AppDatabase _db;
  final FoodRepository _foods;
  Database get _d => _db.db;

  Future<List<SavedMeal>> all() async {
    final rows = await _d.query('saved_meals', orderBy: 'name COLLATE NOCASE');
    return [for (final r in rows) await _load(r)];
  }

  Future<SavedMeal?> byId(int id) async {
    final rows = await _d.query('saved_meals', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _load(rows.first);
  }

  Future<SavedMeal> _load(Map<String, Object?> row) async {
    final itemRows = await _d.query(
      'saved_meal_items',
      where: 'saved_meal_id = ?',
      whereArgs: [row['id']],
      orderBy: 'sort_order, id',
    );
    final items = <SavedMealItem>[];
    for (final r in itemRows) {
      final food = await _foods.byId(r['food_id'] as int);
      if (food == null) continue;
      final label = r['serving_label'] as String?;
      final count = (r['serving_count'] as num?)?.toDouble();
      FoodServing? serving;
      if (label != null && count != null) {
        serving =
            food.servings.where((s) => s.label == label).firstOrNull ??
            // The food's serving list changed; keep the size the meal was saved with.
            FoodServing(label: label, quantity: (r['quantity'] as num).toDouble() / count);
      }
      items.add(
        SavedMealItem(
          id: r['id'] as int,
          sortOrder: r['sort_order'] as int,
          portion: FoodPortion(
            food: food,
            serving: serving,
            count: serving == null ? (r['quantity'] as num).toDouble() : count!,
          ),
        ),
      );
    }
    return SavedMeal(
      id: row['id'] as int,
      name: row['name'] as String,
      category: row['category'] as String,
      description: (row['description'] as String?) ?? '',
      items: items,
    );
  }

  /// Inserts or updates a meal and replaces its items. Returns the meal id.
  /// Past diary entries are unaffected: they hold their own snapshots.
  Future<int> save(SavedMeal meal) {
    if (meal.name.trim().isEmpty) throw ArgumentError('Enter a meal name');
    if (meal.items.isEmpty) throw ArgumentError('Add at least one food');
    if (meal.items.any((i) => i.portion.count <= 0)) throw ArgumentError('Quantities must be greater than 0');
    return _d.transaction((txn) async {
      final now = timestampNow();
      final values = {
        'name': meal.name.trim(),
        'category': meal.category,
        'description': meal.description.trim(),
        'updated_at': now,
      };
      int id;
      if (meal.id == null) {
        id = await txn.insert('saved_meals', {...values, 'created_at': now});
      } else {
        id = meal.id!;
        await txn.update('saved_meals', values, where: 'id = ?', whereArgs: [id]);
        await txn.delete('saved_meal_items', where: 'saved_meal_id = ?', whereArgs: [id]);
      }
      for (var i = 0; i < meal.items.length; i++) {
        final p = meal.items[i].portion;
        await txn.insert('saved_meal_items', {
          'saved_meal_id': id,
          'food_id': p.food.id,
          'quantity': p.baseQuantity,
          'serving_label': p.serving?.label,
          'serving_count': p.serving == null ? null : p.count,
          'sort_order': i,
        });
      }
      return id;
    });
  }

  Future<int> duplicate(int id) async {
    final meal = await byId(id);
    if (meal == null) throw StateError('Meal not found');
    return save(
      SavedMeal(name: '${meal.name} (copy)', category: meal.category, description: meal.description, items: meal.items),
    );
  }

  Future<void> delete(int id) => _d.delete('saved_meals', where: 'id = ?', whereArgs: [id]);
}
