import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/features/nutrition/nutrition_models.dart';

FoodItem food({
  int id = 1,
  double kcal = 200,
  double protein = 10,
  double carbs = 20,
  double fat = 5,
  double? fiber = 2,
  List<FoodServing> servings = const [],
  String unit = 'g',
}) => FoodItem(
  id: id,
  name: 'Test food $id',
  category: 'Other',
  baseUnit: unit,
  per: Nutrients(
    calories: kcal,
    protein: protein,
    carbs: carbs,
    fat: fat,
    fiber: fiber,
    fiberMissing: fiber == null ? 1 : 0,
  ),
  servings: servings,
);

void main() {
  group('nutrient amounts', () {
    test('50 g of a 200 kcal/100 g food is 100 kcal', () {
      expect(nutrientsFor(food(kcal: 200), 50).calories, closeTo(100, 1e-9));
    });

    test('150 g of a 10 g protein/100 g food is 15 g protein', () {
      expect(nutrientsFor(food(protein: 10), 150).protein, closeTo(15, 1e-9));
    });

    test('millilitre foods use values per 100 ml', () {
      final milk = food(kcal: 58, protein: 3.1, unit: 'ml');
      final n = nutrientsFor(milk, 250);
      expect(n.calories, closeTo(145, 1e-9));
      expect(n.protein, closeTo(7.75, 1e-9));
    });

    test('a household serving converts to its defined weight first', () {
      final roti = food(kcal: 255, servings: const [FoodServing(label: '1 medium roti (40 g)', quantity: 40)]);
      final portion = FoodPortion(food: roti, serving: roti.servings.first, count: 2);
      expect(portion.baseQuantity, 80);
      expect(portion.nutrients.calories, closeTo(204, 1e-9));
      expect(portion.quantityLabel, '2 × medium roti (40 g)');
    });

    test('changing the quantity updates every nutrient', () {
      final f = food(kcal: 200, protein: 10, carbs: 20, fat: 5, fiber: 2);
      final small = FoodPortion(food: f, count: 100).nutrients;
      final big = FoodPortion(food: f, count: 300).nutrients;
      expect(big.calories, closeTo(small.calories * 3, 1e-9));
      expect(big.protein, closeTo(small.protein * 3, 1e-9));
      expect(big.carbs, closeTo(small.carbs * 3, 1e-9));
      expect(big.fat, closeTo(small.fat * 3, 1e-9));
      expect(big.fiber, closeTo(small.fiber! * 3, 1e-9));
    });
  });

  group('totals', () {
    test('combining two foods sums their nutrients', () {
      final a = nutrientsFor(food(kcal: 100, protein: 5, carbs: 10, fat: 2, fiber: 1), 100);
      final b = nutrientsFor(food(kcal: 300, protein: 20, carbs: 30, fat: 8, fiber: 4), 50);
      final sum = Nutrients.sum([a, b]);
      expect(sum.calories, closeTo(250, 1e-9));
      expect(sum.protein, closeTo(15, 1e-9));
      expect(sum.carbs, closeTo(25, 1e-9));
      expect(sum.fat, closeTo(6, 1e-9));
      expect(sum.fiber, closeTo(3, 1e-9));
    });

    test('removing a food subtracts exactly its contribution', () {
      final items = [
        nutrientsFor(food(kcal: 120), 100),
        nutrientsFor(food(kcal: 80), 100),
        nutrientsFor(food(kcal: 50), 100),
      ];
      final all = Nutrients.sum(items);
      final withoutSecond = Nutrients.sum([items[0], items[2]]);
      expect(all.calories - withoutSecond.calories, closeTo(80, 1e-9));
    });

    test('a zero-calorie food is valid', () {
      final water = food(kcal: 0, protein: 0, carbs: 0, fat: 0, fiber: 0);
      final n = nutrientsFor(water, 500);
      expect(n.calories, 0);
      expect(n.fiber, 0);
      expect(n.fiberMissing, 0);
    });

    test('missing fibre is tracked, not treated as a verified zero', () {
      final known = nutrientsFor(food(fiber: 4), 100);
      final unknown = nutrientsFor(food(fiber: null), 100);
      expect(unknown.fiber, isNull);
      expect(unknown.fiberMissing, 1);
      final sum = known + unknown;
      expect(sum.fiber, closeTo(4, 1e-9));
      expect(sum.fiberMissing, 1);
      expect((Nutrients.zero + unknown).fiber, isNull);
    });

    test('a meal is multiplied by servings once', () {
      final mealTotal = Nutrients.sum([nutrientsFor(food(kcal: 200), 100), nutrientsFor(food(kcal: 100), 100)]);
      expect(mealTotal.scale(2).calories, closeTo(600, 1e-9));
    });
  });

  group('remaining against target', () {
    test('under target shows remaining', () {
      const p = TargetProgress(1850, 2500);
      expect(p.remaining, 650);
      expect(p.excess, 0);
      expect(p.isOver, isFalse);
      expect(p.fraction, closeTo(0.74, 1e-9));
    });

    test('over target shows excess and keeps the consumed value', () {
      const p = TargetProgress(2700, 2500);
      expect(p.remaining, 0);
      expect(p.excess, 200);
      expect(p.isOver, isTrue);
      expect(p.consumed, 2700);
      expect(p.fraction, 1);
    });

    test('without a target nothing is reported as remaining', () {
      const p = TargetProgress(1200, null);
      expect(p.hasTarget, isFalse);
      expect(p.remaining, isNull);
      expect(p.fraction, 0);
    });
  });
}
