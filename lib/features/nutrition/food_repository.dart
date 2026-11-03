import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/dates.dart';
import 'nutrition_models.dart';

class FoodRepository {
  FoodRepository(this._db);
  final AppDatabase _db;
  Database get _d => _db.db;

  Future<List<FoodItem>> search({
    String query = '',
    String? category,
    int limit = 300,
    bool includeArchived = false,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (!includeArchived) where.add('is_archived = 0');
    final q = query.trim();
    if (q.isNotEmpty) {
      // Match every word, in any order: "dal toor" finds "Toor dal".
      for (final word in q.split(RegExp(r'\s+'))) {
        where.add("name LIKE ? ESCAPE '\\'");
        args.add('%${word.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%');
      }
    }
    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }
    final rows = await _d.query(
      'food_items',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'name COLLATE NOCASE',
      limit: limit,
    );
    return _withServings(rows);
  }

  Future<FoodItem?> byId(int id) async {
    final rows = await _d.query('food_items', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return (await _withServings(rows)).first;
  }

  Future<List<FoodItem>> _withServings(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r['id'] as int).toList();
    final servingRows = await _d.query(
      'food_servings',
      where: 'food_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      orderBy: 'id',
    );
    final byFood = <int, List<FoodServing>>{};
    for (final s in servingRows) {
      byFood.putIfAbsent(s['food_id'] as int, () => []).add(FoodServing.fromMap(s));
    }
    return [for (final r in rows) FoodItem.fromMap(r, byFood[r['id']] ?? const [])];
  }

  /// Categories in use, in the standard order with any custom ones after.
  Future<List<String>> categories() async {
    final rows = await _d.rawQuery('SELECT DISTINCT category FROM food_items WHERE is_archived = 0');
    final used = rows.map((r) => r['category'] as String).toSet();
    return [
      ...foodCategories.where(used.contains),
      ...(used.where((c) => !foodCategories.contains(c)).toList()..sort()),
    ];
  }

  /// Foods most recently logged, newest first.
  Future<List<FoodItem>> recent({int limit = 25}) async {
    final rows = await _d.rawQuery(
      "SELECT source_id, MAX(logged_at) AS last FROM food_logs WHERE source_type = 'food' AND source_id IS NOT NULL "
      'GROUP BY source_id ORDER BY last DESC LIMIT ?',
      [limit],
    );
    final ids = rows.map((r) => r['source_id'] as int).toList();
    if (ids.isEmpty) return const [];
    final foods = await _d.query(
      'food_items',
      where: 'is_archived = 0 AND id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final loaded = {for (final f in await _withServings(foods)) f.id: f};
    return [for (final id in ids) ?loaded[id]];
  }

  String? _validate(FoodItem f) {
    if (f.name.trim().isEmpty) return 'Enter a name';
    if (f.baseUnit != 'g' && f.baseUnit != 'ml') return 'Unit must be g or ml';
    final p = f.per;
    if ([p.calories, p.protein, p.carbs, p.fat].any((v) => v < 0) || (p.fiber ?? 0) < 0) {
      return 'Nutrient values cannot be negative';
    }
    // Fibre is part of total carbohydrate, so it is not added again here.
    if (f.baseUnit == 'g' && p.protein + p.carbs + p.fat > f.baseQuantity * 1.05) {
      return 'Macros add up to more than the food weight';
    }
    for (final s in f.servings) {
      if (s.label.trim().isEmpty || s.quantity <= 0) return 'Every serving needs a name and a size above 0';
    }
    return null;
  }

  Future<int> create(FoodItem food) {
    final error = _validate(food);
    if (error != null) throw ArgumentError(error);
    return _d.transaction((txn) async {
      final now = timestampNow();
      final id = await txn.insert('food_items', {
        ...food.toMap(),
        'is_custom': 1,
        'created_at': now,
        'updated_at': now,
      });
      await _insertServings(txn, id, food.servings);
      return id;
    });
  }

  /// Corrections apply to future logs only: past diary entries keep the
  /// values they were logged with.
  Future<void> update(FoodItem food) {
    final error = _validate(food);
    if (error != null) throw ArgumentError(error);
    return _d.transaction((txn) async {
      await txn.update(
        'food_items',
        {...food.toMap(), 'updated_at': timestampNow()},
        where: 'id = ?',
        whereArgs: [food.id],
      );
      await txn.delete('food_servings', where: 'food_id = ?', whereArgs: [food.id]);
      await _insertServings(txn, food.id, food.servings);
    });
  }

  Future<void> _insertServings(DatabaseExecutor txn, int foodId, List<FoodServing> servings) async {
    for (final s in servings) {
      await txn.insert('food_servings', {
        'food_id': foodId,
        'label': s.label.trim(),
        'quantity': s.quantity,
        'is_estimate': s.isEstimate ? 1 : 0,
        'is_custom': s.isCustom ? 1 : 0,
      });
    }
  }

  /// Foods used in saved meals are archived instead of deleted. Returns true
  /// if archived.
  Future<bool> deleteOrArchive(int id) async {
    final used = await _d.rawQuery('SELECT 1 FROM saved_meal_items WHERE food_id = ? LIMIT 1', [id]);
    if (used.isNotEmpty) {
      await _d.update('food_items', {'is_archived': 1}, where: 'id = ?', whereArgs: [id]);
      return true;
    }
    await _d.delete('food_items', where: 'id = ?', whereArgs: [id]);
    return false;
  }
}
