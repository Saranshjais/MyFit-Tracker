import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';

/// Calories and macros. [fiber] is the sum of known fibre values and is null
/// when no item had a fibre value; [fiberMissing] counts items without one,
/// so missing data is never shown as a verified zero.
@immutable
class Nutrients {
  const Nutrients({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber,
    this.fiberMissing = 0,
  });

  static const zero = Nutrients();

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double? fiber;
  final int fiberMissing;

  Nutrients operator +(Nutrients o) => Nutrients(
    calories: calories + o.calories,
    protein: protein + o.protein,
    carbs: carbs + o.carbs,
    fat: fat + o.fat,
    fiber: fiber == null && o.fiber == null ? null : (fiber ?? 0) + (o.fiber ?? 0),
    fiberMissing: fiberMissing + o.fiberMissing,
  );

  Nutrients scale(double factor) => Nutrients(
    calories: calories * factor,
    protein: protein * factor,
    carbs: carbs * factor,
    fat: fat * factor,
    fiber: fiber == null ? null : fiber! * factor,
    fiberMissing: fiberMissing,
  );

  static Nutrients sum(Iterable<Nutrients> items) => items.fold(zero, (a, b) => a + b);

  Map<String, Object?> toJson() => {
    'calories': calories,
    'protein': protein,
    'carbohydrates': carbs,
    'fat': fat,
    'fiber': fiber,
  };

  @override
  bool operator ==(Object other) =>
      other is Nutrients &&
      other.calories == calories &&
      other.protein == protein &&
      other.carbs == carbs &&
      other.fat == fat &&
      other.fiber == fiber &&
      other.fiberMissing == fiberMissing;

  @override
  int get hashCode => Object.hash(calories, protein, carbs, fat, fiber, fiberMissing);

  @override
  String toString() =>
      'Nutrients(${calories.toStringAsFixed(1)} kcal, P ${protein.toStringAsFixed(1)}, '
      'C ${carbs.toStringAsFixed(1)}, F ${fat.toStringAsFixed(1)}, fibre $fiber, missing $fiberMissing)';
}

/// Consumed amount against a target. Over-target amounts are reported as an
/// excess, never as negative "remaining".
@immutable
class TargetProgress {
  const TargetProgress(this.consumed, this.target);
  final double consumed;
  final double? target;

  bool get hasTarget => target != null && target! > 0;
  double? get remaining => hasTarget ? math.max(0, target! - consumed) : null;
  double? get excess => hasTarget ? math.max(0, consumed - target!) : null;
  bool get isOver => hasTarget && consumed > target! + 1e-9;
  bool get isReached => hasTarget && consumed >= target! - 1e-9;

  /// 0–1 for progress rings.
  double get fraction => hasTarget ? (consumed / target!).clamp(0.0, 1.0) : 0;
}

enum PreparationState {
  raw('Raw'),
  dry('Dry / uncooked'),
  cooked('Cooked'),
  asEaten('As eaten');

  const PreparationState(this.label);
  final String label;

  String get dbValue => this == asEaten ? 'as_eaten' : name;
  static PreparationState fromDb(Object? v) =>
      PreparationState.values.firstWhere((p) => p.dbValue == v, orElse: () => PreparationState.asEaten);
}

const foodCategories = [
  'Roti & Breads',
  'Rice & Grains',
  'Breakfast Dishes',
  'Dal & Legumes',
  'Paneer & Soy',
  'Dairy',
  'Vegetables & Salad',
  'Fruits',
  'Nuts & Seeds',
  'Oils & Fats',
  'Beverages',
  'Supplements',
  'Other',
];

@immutable
class FoodServing {
  const FoodServing({
    this.id,
    required this.label,
    required this.quantity,
    this.isEstimate = true,
    this.isCustom = false,
  });
  final int? id;

  /// e.g. "1 medium roti (40 g)".
  final String label;

  /// Size of one serving in the food's base unit (g or ml).
  final double quantity;
  final bool isEstimate;
  final bool isCustom;

  factory FoodServing.fromMap(Map<String, Object?> m) => FoodServing(
    id: m['id'] as int,
    label: m['label'] as String,
    quantity: (m['quantity'] as num).toDouble(),
    isEstimate: m['is_estimate'] == 1,
    isCustom: m['is_custom'] == 1,
  );
}

@immutable
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    this.foodType = 'vegetarian',
    this.baseUnit = 'g',
    this.baseQuantity = 100,
    required this.per,
    this.preparationState = PreparationState.asEaten,
    this.source = '',
    this.isEstimate = true,
    this.isCustom = false,
    this.isArchived = false,
    this.servings = const [],
  });

  final int id;
  final String name;
  final String category;
  final String foodType;

  /// "g" or "ml".
  final String baseUnit;

  /// Amount (in [baseUnit]) that [per] describes, normally 100.
  final double baseQuantity;
  final Nutrients per;
  final PreparationState preparationState;
  final String source;
  final bool isEstimate;
  final bool isCustom;
  final bool isArchived;
  final List<FoodServing> servings;

  FoodServing? get defaultServing => servings.isEmpty ? null : servings.first;

  factory FoodItem.fromMap(Map<String, Object?> m, List<FoodServing> servings) {
    final fiber = (m['fiber'] as num?)?.toDouble();
    return FoodItem(
      id: m['id'] as int,
      name: m['name'] as String,
      category: m['category'] as String,
      foodType: (m['food_type'] as String?) ?? 'vegetarian',
      baseUnit: m['base_unit'] as String,
      baseQuantity: (m['base_quantity'] as num).toDouble(),
      per: Nutrients(
        calories: (m['calories'] as num).toDouble(),
        protein: (m['protein'] as num).toDouble(),
        carbs: (m['carbohydrates'] as num).toDouble(),
        fat: (m['fat'] as num).toDouble(),
        fiber: fiber,
        fiberMissing: fiber == null ? 1 : 0,
      ),
      preparationState: PreparationState.fromDb(m['preparation_state']),
      source: (m['source'] as String?) ?? '',
      isEstimate: m['is_estimate'] == 1,
      isCustom: m['is_custom'] == 1,
      isArchived: m['is_archived'] == 1,
      servings: servings,
    );
  }

  Map<String, Object?> toMap() => {
    'name': name.trim(),
    'category': category,
    'food_type': foodType,
    'base_unit': baseUnit,
    'base_quantity': baseQuantity,
    'calories': per.calories,
    'protein': per.protein,
    'carbohydrates': per.carbs,
    'fat': per.fat,
    'fiber': per.fiber,
    'preparation_state': preparationState.dbValue,
    'source': source.trim(),
    'is_estimate': isEstimate ? 1 : 0,
    'is_custom': isCustom ? 1 : 0,
    'is_archived': isArchived ? 1 : 0,
  };
}

/// Nutrients for [quantity] of [food], in the food's base unit:
/// value per base quantity × quantity ÷ base quantity
/// (with the usual 100 g base: value per 100 g × grams ÷ 100).
Nutrients nutrientsFor(FoodItem food, double quantity) => food.per.scale(quantity / food.baseQuantity);

/// "2 × medium roti (40 g)" for 2 servings, the label itself for 1.
String servingDisplay(double count, String label) {
  if ((count - 1).abs() < 1e-9) return label;
  return '${formatNumber(count, decimals: 2)} × ${label.replaceFirst(RegExp(r'^1\s+'), '')}';
}

/// An amount of a food chosen by the user: [count] servings, or [count] grams
/// or millilitres when [serving] is null.
@immutable
class FoodPortion {
  const FoodPortion({required this.food, this.serving, required this.count});
  final FoodItem food;
  final FoodServing? serving;
  final double count;

  /// Quantity in the food's base unit.
  double get baseQuantity => serving == null ? count : count * serving!.quantity;
  Nutrients get nutrients => nutrientsFor(food, baseQuantity);

  String get unitLabel => serving?.label ?? food.baseUnit;

  String get quantityLabel =>
      serving == null ? '${formatNumber(count, decimals: 1)} ${food.baseUnit}' : servingDisplay(count, serving!.label);

  FoodPortion copyWith({FoodServing? serving, bool clearServing = false, double? count}) =>
      FoodPortion(food: food, serving: clearServing ? null : (serving ?? this.serving), count: count ?? this.count);
}

/// Ingredient snapshot stored with a logged meal.
@immutable
class IngredientSnapshot {
  const IngredientSnapshot({required this.name, required this.quantityLabel, required this.nutrients});
  final String name;
  final String quantityLabel;
  final Nutrients nutrients;

  Map<String, Object?> toJson() => {'name': name, 'quantity': quantityLabel, ...nutrients.toJson()};

  factory IngredientSnapshot.fromJson(Map<String, dynamic> j) {
    final fiber = (j['fiber'] as num?)?.toDouble();
    return IngredientSnapshot(
      name: j['name'] as String,
      quantityLabel: (j['quantity'] as String?) ?? '',
      nutrients: Nutrients(
        calories: (j['calories'] as num).toDouble(),
        protein: (j['protein'] as num).toDouble(),
        carbs: (j['carbohydrates'] as num).toDouble(),
        fat: (j['fat'] as num).toDouble(),
        fiber: fiber,
        fiberMissing: fiber == null ? 1 : 0,
      ),
    );
  }
}

enum FoodLogSource { food, meal }

/// A diary entry. Its nutrients are a snapshot taken when it was logged, so
/// later edits to the food or saved meal never change past days.
@immutable
class FoodLog {
  const FoodLog({
    required this.id,
    required this.date,
    required this.mealCategory,
    required this.loggedAt,
    required this.sourceType,
    this.sourceId,
    required this.displayName,
    required this.quantity,
    required this.unit,
    this.baseQuantity,
    required this.nutrients,
    this.ingredients = const [],
    this.notes = '',
  });

  final int id;
  final String date;
  final String mealCategory;
  final DateTime loggedAt;
  final FoodLogSource sourceType;
  final int? sourceId;
  final String displayName;

  /// Number of servings (meal or food serving), or grams/ml when [unit] is
  /// "g" or "ml".
  final double quantity;
  final String unit;
  final double? baseQuantity;
  final Nutrients nutrients;
  final List<IngredientSnapshot> ingredients;
  final String notes;

  bool get isBaseUnit => unit == 'g' || unit == 'ml';

  String get quantityLabel {
    if (sourceType == FoodLogSource.meal) {
      return '${formatNumber(quantity, decimals: 2)} ${quantity == 1 ? 'serving' : 'servings'}';
    }
    if (isBaseUnit) return '${formatNumber(quantity, decimals: 1)} $unit';
    return servingDisplay(quantity, unit);
  }

  factory FoodLog.fromMap(Map<String, Object?> m) {
    final detail = m['detail'] as String?;
    return FoodLog(
      id: m['id'] as int,
      date: m['date'] as String,
      mealCategory: m['meal_category'] as String,
      loggedAt: parseTimestamp(m['logged_at'] as String),
      sourceType: m['source_type'] == 'meal' ? FoodLogSource.meal : FoodLogSource.food,
      sourceId: m['source_id'] as int?,
      displayName: m['display_name'] as String,
      quantity: (m['quantity'] as num).toDouble(),
      unit: m['unit'] as String,
      baseQuantity: (m['base_quantity'] as num?)?.toDouble(),
      nutrients: Nutrients(
        calories: (m['calories'] as num).toDouble(),
        protein: (m['protein'] as num).toDouble(),
        carbs: (m['carbohydrates'] as num).toDouble(),
        fat: (m['fat'] as num).toDouble(),
        fiber: (m['fiber'] as num?)?.toDouble(),
        fiberMissing: (m['fiber_missing'] as int?) ?? 0,
      ),
      ingredients: detail == null
          ? const []
          : (jsonDecode(detail) as List).map((e) => IngredientSnapshot.fromJson(e as Map<String, dynamic>)).toList(),
      notes: (m['notes'] as String?) ?? '',
    );
  }
}

@immutable
class SavedMealItem {
  const SavedMealItem({this.id, required this.portion, this.sortOrder = 0});
  final int? id;
  final FoodPortion portion;
  final int sortOrder;
}

@immutable
class SavedMeal {
  const SavedMeal({this.id, required this.name, required this.category, this.description = '', this.items = const []});
  final int? id;
  final String name;
  final String category;
  final String description;
  final List<SavedMealItem> items;

  /// Uses the foods' current values (a saved meal is a recipe, not a log).
  Nutrients get nutrients => Nutrients.sum(items.map((i) => i.portion.nutrients));

  String get summary => items.map((i) => i.portion.food.name).join(' + ');
}
