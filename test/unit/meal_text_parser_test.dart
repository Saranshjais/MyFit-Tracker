import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/core/database/app_database.dart';
import 'package:myfit_tracker/features/nutrition/food_repository.dart';
import 'package:myfit_tracker/features/nutrition/nutrition_models.dart';
import 'package:myfit_tracker/features/nutrition/quick_log/meal_text_parser.dart';

import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late MealTextParser parser;

  setUpAll(() async {
    db = await openTestDatabase(path: tempDatabasePath('parser'));
    parser = MealTextParser(await FoodRepository(db).search(limit: 1000));
  });

  tearDownAll(() => db.close());

  List<ParsedFood> parse(String s) => parser.parse(s).items;
  String names(String s) => parse(s).map((p) => p.food?.name ?? '?${p.phrase}').join(' | ');

  test('every alias points at a food in the database', () async {
    final foods = (await FoodRepository(db).search(limit: 1000)).map((f) => f.name).toSet();
    for (final entry in MealTextParser.aliases.entries) {
      expect(foods, contains(entry.value), reason: 'alias "${entry.key}"');
    }
  });

  test('the example sentence', () {
    final items = parse('2 roti, 1 bowl dal, 1 glass milk and a banana');
    expect(items.map((p) => p.food!.name), [
      'Roti (whole wheat, no ghee)',
      'Toor dal (cooked, tempered)',
      'Milk, toned (3% fat)',
      'Banana',
    ]);
    expect(items[0].count, 2);
    expect(items[0].serving!.label, '1 medium roti (40 g)');
    expect(items[0].portion!.nutrients.calories, closeTo(204, 0.01));
    expect(items[1].serving!.label, '1 bowl (150 g)', reason: 'plain bowl preferred over small bowl');
    expect(items[2].serving!.label, '1 glass (250 ml)');
    expect(items[3].count, 1);
    expect(items.every((p) => p.confident && !p.servingEstimated), isTrue);
  });

  test('works without commas: a new number starts a new food', () {
    expect(
      names('2 roti 1 bowl dal 200 ml milk'),
      'Roti (whole wheat, no ghee) | Toor dal (cooked, tempered) | Milk, toned (3% fat)',
    );
    final milk = parse('2 roti 1 bowl dal 200 ml milk').last;
    expect(milk.serving, isNull);
    expect(milk.count, 200);
  });

  test('Hindi and Hinglish', () {
    final items = parse('do roti aur ek katori dal, aadha glass doodh');
    expect(items.map((p) => p.food!.name), [
      'Roti (whole wheat, no ghee)',
      'Toor dal (cooked, tempered)',
      'Milk, toned (3% fat)',
    ]);
    expect(items[0].count, 2);
    expect(items[1].count, 1);
    expect(items[2].count, 0.5);
    expect(names('dahi chawal'), 'Curd (whole milk) | Cooked white rice');
    expect(names('ek kela aur chai'), 'Banana | Tea with milk and sugar');
    expect(names('dedh katori rajma'), 'Rajma curry');
    expect(parse('dedh katori rajma').single.count, 1.5);
    expect(names('chaas'), 'Buttermilk (chaas)');
  });

  test('grams, kilos and plural words', () {
    final paneer = parse('100g paneer').single;
    expect(paneer.food!.name, 'Paneer (full fat)');
    expect(paneer.serving, isNull);
    expect(paneer.count, 100);
    expect(parse('3 rotis').single.count, 3);
    expect(names('10 almonds'), 'Almonds');
    expect(parse('0.5 kg curd').single.count, 500);
  });

  test('longer names win over shorter ones', () {
    expect(names('1 bowl moong dal'), 'Moong dal (cooked)');
    expect(names('masala dosa'), 'Masala dosa');
    expect(names('a glass of full cream milk'), 'Milk, full cream (6% fat)');
    expect(names('2 spoon peanut butter'), 'Peanut butter');
  });

  test('fractions and "and a half"', () {
    expect(parse('one and a half roti').single.count, 1.5);
    expect(parse('1/2 cup rice').single.count, 0.5);
    expect(parse('½ bowl dal').single.count, 0.5);
  });

  test('sizes pick the matching serving', () {
    expect(parse('1 large roti').single.serving!.label, '1 large roti (55 g)');
    expect(parse('2 small bananas').single.serving!.label, '1 small banana (101 g)');
  });

  test('amount after the food still applies', () {
    final roti = parse('roti do').single;
    expect(roti.count, 2);
    final dish = parse('rajma chawal 1 plate');
    expect(dish.map((p) => p.food!.name), ['Rajma curry', 'Cooked white rice']);
    expect(dish.first.count, 1);
  });

  test('an amount word with no matching serving uses a standard size, flagged as estimated', () {
    final item = parse('1 bowl paneer').single;
    expect(item.food!.name, 'Paneer (full fat)');
    expect(item.servingEstimated, isTrue);
    expect(item.serving!.quantity, 150);
  });

  test('spoon prefers a teaspoon serving for ghee and sugar', () {
    expect(parse('1 spoon ghee').single.serving!.label, '1 tsp (5 g)');
    expect(parse('2 spoon sugar').single.serving!.label, '1 tsp (4 g)');
  });

  test('unknown foods are reported, never guessed', () {
    final items = parse('2 roti and a pizza');
    expect(items.first.matched, isTrue);
    expect(items.last.matched, isFalse);
    expect(items.last.phrase, contains('pizza'));
  });

  test('loose matches are marked for checking', () {
    final butter = parse('1 spoon butter').single;
    expect(butter.food!.name, 'Peanut butter');
    expect(butter.confident, isFalse);
  });

  test('custom foods are found too', () {
    final custom = FoodItem(
      id: 9999,
      name: 'Besan chilla',
      category: 'Breakfast Dishes',
      per: const Nutrients(calories: 180, protein: 9, carbs: 22, fat: 6),
      servings: const [FoodServing(label: '1 chilla (70 g)', quantity: 70)],
    );
    final p = MealTextParser([...parser.foods, custom]).parse('2 besan chilla').items.single;
    expect(p.food!.name, 'Besan chilla');
    expect(p.portion!.baseQuantity, 140);
  });

  test('meal names in the sentence are detected and not treated as food', () {
    final r = parser.parse('for breakfast I had 2 idli and sambar');
    expect(r.mealCategory, 'Breakfast');
    expect(r.items.map((p) => p.food!.name), ['Idli', 'Sambar']);
    expect(parser.parse('raat ko khichdi khayi').mealCategory, 'Dinner');
    expect(parser.parse('lunch me dal chawal').items.length, 2);
  });

  test('empty or filler-only text gives nothing', () {
    expect(parse(''), isEmpty);
    expect(parse('I had for lunch'), isEmpty);
  });
}
