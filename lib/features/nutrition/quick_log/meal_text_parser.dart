import 'package:flutter/foundation.dart';

import '../nutrition_models.dart';

/// One food understood from a spoken or typed sentence.
@immutable
class ParsedFood {
  const ParsedFood({
    required this.phrase,
    this.food,
    this.serving,
    this.count = 1,
    this.servingEstimated = false,
    this.confident = true,
  });

  /// The words this item came from, e.g. "2 roti".
  final String phrase;

  /// Null when no food in the database matched.
  final FoodItem? food;

  /// Null means [count] is in the food's base unit (g or ml).
  final FoodServing? serving;
  final double count;

  /// True when the amount word ("bowl", "glass") had no matching serving
  /// for this food and a standard household size was assumed.
  final bool servingEstimated;

  /// False for a loose match the user should double-check.
  final bool confident;

  bool get matched => food != null;

  FoodPortion? get portion => food == null ? null : FoodPortion(food: food!, serving: serving, count: count);
}

@immutable
class ParseResult {
  const ParseResult(this.items, {this.mealCategory});
  final List<ParsedFood> items;

  /// Meal named in the sentence ("for lunch", "nashta"), if any.
  final String? mealCategory;

  static const empty = ParseResult([]);
}

enum _Unit { gram, kg, ml, litre, bowl, glass, cup, plate, piece, slice, spoon, tbsp, tsp, scoop, handful }

/// Turns sentences like "2 roti, 1 bowl dal aur ek glass doodh" into foods
/// and amounts using only the local food list. Nothing is sent anywhere.
///
/// It understands English and common Hindi number, amount and food words.
/// Anything it cannot match is returned unmatched rather than guessed.
class MealTextParser {
  MealTextParser(this.foods) : _byName = {for (final f in foods) f.name.toLowerCase(): f};

  final List<FoodItem> foods;
  final Map<String, FoodItem> _byName;

  ParseResult parse(String text) {
    final tokens = _tokenize(text);
    if (tokens.isEmpty) return ParseResult.empty;
    final meal = _detectMeal(tokens);
    final items = <ParsedFood>[];
    for (final segment in _segments(tokens)) {
      items.addAll(_parseSegment(segment));
    }
    return ParseResult(items, mealCategory: meal);
  }

  // ---------------------------------------------------------------------------
  // Words

  static const _numberWords = <String, double>{
    'a': 1, 'an': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, //
    'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12,
    'half': 0.5, 'quarter': 0.25, 'couple': 2,
    'ek': 1, 'do': 2, 'teen': 3, 'char': 4, 'chaar': 4, 'paanch': 5, 'panch': 5, //
    'chhe': 6, 'che': 6, 'saat': 7, 'aath': 8, 'nau': 9, 'das': 10,
    'aadha': 0.5, 'adha': 0.5, 'aadhi': 0.5, 'adhi': 0.5, 'dedh': 1.5, 'dhai': 2.5, 'dhaai': 2.5, 'sawa': 1.25,
  };

  static const _unitWords = <String, _Unit>{
    'g': _Unit.gram, 'gm': _Unit.gram, 'gms': _Unit.gram, 'gram': _Unit.gram, 'grams': _Unit.gram, //
    'gramme': _Unit.gram, 'grammes': _Unit.gram,
    'kg': _Unit.kg, 'kgs': _Unit.kg, 'kilo': _Unit.kg, 'kilos': _Unit.kg, 'kilogram': _Unit.kg,
    'ml': _Unit.ml, 'mls': _Unit.ml, 'millilitre': _Unit.ml, 'millilitres': _Unit.ml, //
    'milliliter': _Unit.ml, 'milliliters': _Unit.ml,
    'litre': _Unit.litre, 'litres': _Unit.litre, 'liter': _Unit.litre, 'liters': _Unit.litre,
    'bowl': _Unit.bowl, 'bowls': _Unit.bowl, 'katori': _Unit.bowl, 'katoris': _Unit.bowl, 'kathori': _Unit.bowl,
    'glass': _Unit.glass, 'glasses': _Unit.glass, 'gilas': _Unit.glass,
    'cup': _Unit.cup, 'cups': _Unit.cup, 'mug': _Unit.cup, 'mugs': _Unit.cup,
    'plate': _Unit.plate, 'plates': _Unit.plate,
    'piece': _Unit.piece, 'pieces': _Unit.piece, 'pc': _Unit.piece, 'pcs': _Unit.piece,
    'slice': _Unit.slice, 'slices': _Unit.slice,
    'spoon': _Unit.spoon,
    'spoons': _Unit.spoon,
    'chammach': _Unit.spoon,
    'chamach': _Unit.spoon,
    'chamcha': _Unit.spoon,
    'tablespoon': _Unit.tbsp, 'tablespoons': _Unit.tbsp, 'tbsp': _Unit.tbsp,
    'teaspoon': _Unit.tsp, 'teaspoons': _Unit.tsp, 'tsp': _Unit.tsp,
    'scoop': _Unit.scoop, 'scoops': _Unit.scoop,
    'handful': _Unit.handful, 'handfuls': _Unit.handful, 'mutthi': _Unit.handful, 'muththi': _Unit.handful,
  };

  /// Words a serving label must contain to match the unit, in preference order.
  static const _unitLabelWords = <_Unit, List<String>>{
    _Unit.bowl: ['bowl', 'katori'],
    _Unit.glass: ['glass'],
    _Unit.cup: ['cup'],
    _Unit.plate: ['plate'],
    _Unit.slice: ['slice'],
    _Unit.spoon: ['tsp', 'tbsp'],
    _Unit.tbsp: ['tbsp'],
    _Unit.tsp: ['tsp'],
    _Unit.scoop: ['scoop'],
    _Unit.handful: ['handful'],
  };

  static const _sizeWords = <String, String>{
    'small': 'small',
    'chhota': 'small',
    'chota': 'small',
    'chhoti': 'small',
    'choti': 'small',
    'medium': 'medium',
    'regular': 'medium',
    'large': 'large',
    'big': 'large',
    'bada': 'large',
    'badi': 'large',
  };

  static const _separators = {',', 'and', 'aur', 'plus', 'with', 'then', 'also', 'along', 'saath'};

  static const _fillers = {
    'i', 'ate', 'eat', 'eaten', 'eating', 'had', 'have', 'having', 'drank', 'drink', 'drunk', 'took', 'take', //
    'of', 'the', 'some', 'my', 'for', 'in', 'at', 'on', 'today', 'just', 'about', 'around', 'approx', 'roughly',
    'khaya',
    'khayi',
    'khaye',
    'khana',
    'piya',
    'pi',
    'liya',
    'li',
    'le',
    'ke',
    'ki',
    'ka',
    'me',
    'mein',
    'maine',
    'hai',
    'breakfast', 'nashta', 'lunch', 'dinner', 'snack', 'snacks', 'meal', 'morning', 'evening', 'night', //
    'raat', 'subah', 'shaam', 'dopahar', 'afternoon',
  };

  static const _mealWords = <String, String>{
    'breakfast': 'Breakfast',
    'nashta': 'Breakfast',
    'subah': 'Breakfast',
    'morning': 'Breakfast',
    'lunch': 'Lunch',
    'dopahar': 'Lunch',
    'afternoon': 'Lunch',
    'snack': 'Evening Snack',
    'snacks': 'Evening Snack',
    'evening': 'Evening Snack',
    'shaam': 'Evening Snack',
    'dinner': 'Dinner',
    'night': 'Dinner',
    'raat': 'Dinner',
  };

  /// Everyday and Hindi names → food names in the bundled database.
  static const aliases = <String, String>{
    'roti': 'Roti (whole wheat, no ghee)', 'chapati': 'Roti (whole wheat, no ghee)', //
    'chapathi': 'Roti (whole wheat, no ghee)', 'chapatti': 'Roti (whole wheat, no ghee)',
    'phulka': 'Roti (whole wheat, no ghee)', 'fulka': 'Roti (whole wheat, no ghee)',
    'ghee roti': 'Roti with ghee',
    'paratha': 'Plain paratha', 'parantha': 'Plain paratha', 'prantha': 'Plain paratha',
    'bread': 'Whole wheat bread', 'toast': 'Whole wheat bread', 'brown bread': 'Whole wheat bread',
    'atta': 'Whole wheat flour (atta)',
    'rice': 'Cooked white rice', 'chawal': 'Cooked white rice', 'chaawal': 'Cooked white rice', //
    'bhaat': 'Cooked white rice', 'white rice': 'Cooked white rice', 'plain rice': 'Cooked white rice',
    'brown rice': 'Cooked brown rice',
    'oat': 'Oats (rolled, dry)', 'oatmeal': 'Oats (rolled, dry)',
    'poha': 'Poha (cooked, home-style)',
    'khichdi': 'Khichdi (moong dal & rice)',
    'khichri': 'Khichdi (moong dal & rice)',
    'khichadi': 'Khichdi (moong dal & rice)',
    'upma': 'Upma', 'idli': 'Idli', 'idly': 'Idli',
    'dosa': 'Plain dosa', 'plain dosa': 'Plain dosa', 'masala dosa': 'Masala dosa',
    'sambar': 'Sambar', 'sambhar': 'Sambar',
    'dal': 'Toor dal (cooked, tempered)', 'daal': 'Toor dal (cooked, tempered)', 'dhal': 'Toor dal (cooked, tempered)',
    'toor dal': 'Toor dal (cooked, tempered)', 'arhar dal': 'Toor dal (cooked, tempered)', //
    'arhar': 'Toor dal (cooked, tempered)', 'tuvar dal': 'Toor dal (cooked, tempered)',
    'yellow dal': 'Toor dal (cooked, tempered)',
    'moong dal': 'Moong dal (cooked)', 'mung dal': 'Moong dal (cooked)', 'moong daal': 'Moong dal (cooked)',
    'rajma': 'Rajma curry', 'kidney bean': 'Kidney beans (boiled)',
    'chole': 'Chole (chickpea curry)', 'chhole': 'Chole (chickpea curry)', 'chana masala': 'Chole (chickpea curry)',
    'chana': 'Chickpeas (boiled)', 'chickpea': 'Chickpeas (boiled)', 'kabuli chana': 'Chickpeas (boiled)',
    'sprout': 'Moong sprouts (raw)', 'moong sprout': 'Moong sprouts (raw)', 'ankurit': 'Moong sprouts (raw)',
    'paneer': 'Paneer (full fat)', 'low fat paneer': 'Low-fat paneer', 'palak paneer': 'Palak paneer',
    'tofu': 'Tofu (firm)',
    'soya chunk': 'Soy chunks (dry)', 'soy chunk': 'Soy chunks (dry)', 'soya': 'Soy chunks (dry)', //
    'nutrela': 'Soy chunks (dry)',
    'milk': 'Milk, toned (3% fat)', 'doodh': 'Milk, toned (3% fat)', 'dudh': 'Milk, toned (3% fat)', //
    'toned milk': 'Milk, toned (3% fat)',
    'full cream milk': 'Milk, full cream (6% fat)', 'full fat milk': 'Milk, full cream (6% fat)',
    'double toned milk': 'Milk, double toned (1.5% fat)', 'skimmed milk': 'Milk, double toned (1.5% fat)', //
    'skim milk': 'Milk, double toned (1.5% fat)', 'low fat milk': 'Milk, double toned (1.5% fat)',
    'curd': 'Curd (whole milk)', 'dahi': 'Curd (whole milk)', 'yogurt': 'Curd (whole milk)', //
    'yoghurt': 'Curd (whole milk)',
    'greek yogurt': 'Greek yogurt (plain, non-fat)', 'greek yoghurt': 'Greek yogurt (plain, non-fat)', //
    'hung curd': 'Greek yogurt (plain, non-fat)',
    'buttermilk': 'Buttermilk (chaas)', 'chaas': 'Buttermilk (chaas)', 'chhaas': 'Buttermilk (chaas)', //
    'chaach': 'Buttermilk (chaas)', 'mattha': 'Buttermilk (chaas)',
    'sabzi': 'Mixed vegetable sabzi', 'sabji': 'Mixed vegetable sabzi', 'subzi': 'Mixed vegetable sabzi', //
    'subji': 'Mixed vegetable sabzi', 'vegetable': 'Mixed vegetable sabzi', 'veg': 'Mixed vegetable sabzi', //
    'mix veg': 'Mixed vegetable sabzi', 'mixed veg': 'Mixed vegetable sabzi', 'bhaji': 'Mixed vegetable sabzi',
    'salad': 'Green salad (cucumber, tomato, onion)',
    'banana': 'Banana', 'kela': 'Banana', 'kele': 'Banana',
    'apple': 'Apple', 'seb': 'Apple',
    'orange': 'Orange', 'santra': 'Orange', 'santara': 'Orange', 'narangi': 'Orange',
    'papaya': 'Papaya', 'papita': 'Papaya',
    'almond': 'Almonds', 'badam': 'Almonds',
    'peanut': 'Peanuts (raw)', 'moongphali': 'Peanuts (raw)', 'mungfali': 'Peanuts (raw)', //
    'moongfali': 'Peanuts (raw)', 'groundnut': 'Peanuts (raw)',
    'peanut butter': 'Peanut butter',
    'walnut': 'Walnuts', 'akhrot': 'Walnuts',
    'ghee': 'Ghee', 'desi ghee': 'Ghee',
    'oil': 'Cooking oil (vegetable)', 'tel': 'Cooking oil (vegetable)', 'cooking oil': 'Cooking oil (vegetable)',
    'sugar': 'Sugar', 'cheeni': 'Sugar', 'chini': 'Sugar', 'shakkar': 'Sugar',
    'tea': 'Tea with milk and sugar', 'chai': 'Tea with milk and sugar', 'chay': 'Tea with milk and sugar',
    'whey': 'Whey protein powder', 'protein': 'Whey protein powder', 'protein shake': 'Whey protein powder', //
    'whey protein': 'Whey protein powder', 'protein powder': 'Whey protein powder',
  };

  /// Standard household sizes used when a food has no matching serving.
  static double _householdSize(_Unit unit, String baseUnit) => switch (unit) {
    _Unit.bowl => 150,
    _Unit.glass => 250,
    _Unit.cup => baseUnit == 'ml' ? 200 : 150,
    _Unit.plate => 150,
    _Unit.slice => 28,
    _Unit.spoon || _Unit.tsp => 5,
    _Unit.tbsp => 15,
    _Unit.scoop => 30,
    _Unit.handful => 30,
    _ => 100,
  };

  static String _unitName(_Unit unit) => switch (unit) {
    _Unit.spoon => 'spoon',
    _Unit.tbsp => 'tbsp',
    _Unit.tsp => 'tsp',
    _ => unit.name,
  };

  // ---------------------------------------------------------------------------
  // Tokens and segments

  static String _singular(String w) {
    if (w.length > 4 && w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
    if (w.length > 4 && (w.endsWith('oes') || w.endsWith('ches') || w.endsWith('shes'))) {
      return w.substring(0, w.length - 2);
    }
    if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) return w.substring(0, w.length - 1);
    return w;
  }

  List<String> _tokenize(String text) {
    var s = text.toLowerCase();
    s = s.replaceAll('½', ' 0.5 ').replaceAll('¼', ' 0.25 ').replaceAll('¾', ' 0.75 ');
    s = s.replaceAllMapped(RegExp(r'(\d+)\s*/\s*(\d+)'), (m) {
      final d = int.parse(m[2]!);
      return d == 0 ? ' ' : ' ${int.parse(m[1]!) / d} ';
    });
    // Glue units to numbers apart: "100g" → "100 g", "250ml" → "250 ml".
    s = s.replaceAllMapped(RegExp(r'(\d)([a-z])'), (m) => '${m[1]} ${m[2]}');
    s = s.replaceAll(RegExp(r'[-_]'), ' ');
    // Keep decimal points; turn other punctuation into separators.
    s = s.replaceAllMapped(RegExp(r'(?<!\d)\.|\.(?!\d)'), (_) => ' , ');
    s = s.replaceAll(RegExp(r'[,;:!?&+/\n]'), ' , ');
    s = s.replaceAll(RegExp(r"[^a-z0-9., ]"), ' ');
    final raw = s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    // "one and a half", "2 and half" → 1.5, 2.5
    final out = <String>[];
    for (var i = 0; i < raw.length; i++) {
      final n = _number(raw[i]);
      if (n != null && n >= 1 && i + 2 < raw.length && raw[i + 1] == 'and') {
        if (raw[i + 2] == 'half') {
          out.add('${n + 0.5}');
          i += 2;
          continue;
        }
        if (raw[i + 2] == 'a' && i + 3 < raw.length && raw[i + 3] == 'half') {
          out.add('${n + 0.5}');
          i += 3;
          continue;
        }
      }
      out.add(raw[i]);
    }
    return out;
  }

  static double? _number(String t) => double.tryParse(t) ?? _numberWords[t];

  bool _isFoodWord(String t) =>
      !_fillers.contains(t) &&
      !_separators.contains(t) &&
      _number(t) == null &&
      !_unitWords.containsKey(t) &&
      !_sizeWords.containsKey(t);

  String? _detectMeal(List<String> tokens) {
    for (final t in tokens) {
      final meal = _mealWords[t];
      if (meal != null) return meal;
    }
    return null;
  }

  /// Splits on separators, and where a new number starts after a food word:
  /// "2 roti 1 bowl dal" → ["2 roti", "1 bowl dal"].
  List<List<String>> _segments(List<String> tokens) {
    final segments = <List<String>>[];
    var current = <String>[];
    void close() {
      if (current.isNotEmpty) segments.add(current);
      current = <String>[];
    }

    for (final t in tokens) {
      if (_separators.contains(t)) {
        close();
        continue;
      }
      final isNumber = _number(t) != null && t != 'a' && t != 'an';
      if (isNumber && current.any(_isFoodWord)) close();
      current.add(t);
    }
    close();

    // An amount after the food ("roti do", "rajma chawal 1 plate") belongs
    // to the food before it.
    final merged = <List<String>>[];
    for (final seg in segments) {
      final hasFood = seg.any(_isFoodWord);
      final prevHasAmount = merged.isNotEmpty && merged.last.any((t) => _number(t) != null);
      if (!hasFood && merged.isNotEmpty && !prevHasAmount) {
        merged.last.addAll(seg);
      } else {
        merged.add(seg);
      }
    }
    return merged;
  }

  // ---------------------------------------------------------------------------
  // Segment → foods

  List<ParsedFood> _parseSegment(List<String> words) {
    double? amount;
    _Unit? unit;
    String? size;
    final foodWords = <String>[];
    for (final w in words) {
      final n = _number(w);
      if (n != null && amount == null) {
        amount = n;
        continue;
      }
      if (n != null) {
        amount = amount! * n; // "half a glass", "2 half" → multiply
        continue;
      }
      if (unit == null && _unitWords.containsKey(w)) {
        unit = _unitWords[w];
        continue;
      }
      if (size == null && _sizeWords.containsKey(w)) {
        size = _sizeWords[w];
        continue;
      }
      if (_isFoodWord(w)) foodWords.add(w);
    }
    if (foodWords.isEmpty) return const [];
    final phrase = words.where((w) => !_fillers.contains(w) || _numberWords.containsKey(w)).join(' ');

    // Known names first, longest phrase wins ("moong dal" before "dal").
    final hits = <FoodItem>[];
    final leftover = <String>[];
    var i = 0;
    while (i < foodWords.length) {
      FoodItem? hit;
      var len = 0;
      for (var l = 3; l >= 1 && hit == null; l--) {
        if (i + l > foodWords.length) continue;
        final words = foodWords.sublist(i, i + l);
        // As spoken first ("chaas"), then singular ("rotis" → "roti").
        final name = aliases[words.join(' ')] ?? aliases[words.map(_singular).join(' ')];
        final food = name == null ? null : _byName[name.toLowerCase()];
        if (food != null) {
          hit = food;
          len = l;
        }
      }
      if (hit != null) {
        if (!hits.contains(hit)) hits.add(hit);
        i += len;
      } else {
        leftover.add(foodWords[i]);
        i++;
      }
    }

    final unsure = <FoodItem>{};
    final fuzzyQuery = hits.isEmpty ? foodWords : leftover;
    if (fuzzyQuery.isNotEmpty) {
      final match = _fuzzy(fuzzyQuery, strict: hits.isNotEmpty);
      if (match != null && !hits.contains(match.food)) {
        hits.add(match.food);
        if (!match.confident) unsure.add(match.food);
      }
    }

    if (hits.isEmpty) return [ParsedFood(phrase: phrase)];
    return [
      for (var k = 0; k < hits.length; k++)
        // The amount belongs to the first food named; others count as one.
        _withAmount(
          k == 0 ? phrase : hits[k].name.toLowerCase(),
          hits[k],
          k == 0 ? amount : null,
          k == 0 ? unit : null,
          k == 0 ? size : null,
          confident: !unsure.contains(hits[k]),
        ),
    ];
  }

  /// Best food whose name contains the query words. With [strict] every
  /// query word must match (used for words left over after a known name).
  ({FoodItem food, bool confident})? _fuzzy(List<String> rawQuery, {required bool strict}) {
    final query = rawQuery.map(_singular).toList();
    FoodItem? best;
    var bestScore = 0.0;
    var bestConfident = false;
    for (final f in foods) {
      final nameWords = f.name
          .toLowerCase()
          .split(RegExp(r'[^a-z0-9]+'))
          .where((w) => w.isNotEmpty)
          .map(_singular)
          .toList();
      var matched = 0;
      for (final q in query) {
        if (nameWords.any((n) => n == q || (q.length >= 4 && n.startsWith(q)) || (n.length >= 4 && q.startsWith(n)))) {
          matched++;
        }
      }
      if (matched == 0) continue;
      final coverage = matched / query.length;
      if (strict && coverage < 1) continue;
      var score = coverage + 0.2 * matched / nameWords.length;
      // People log what they ate: prefer cooked/as-eaten over raw or dry.
      if (f.preparationState == PreparationState.raw || f.preparationState == PreparationState.dry) score -= 0.05;
      if (score > bestScore || (score == bestScore && best != null && f.name.length < best.name.length)) {
        best = f;
        bestScore = score;
        // Confident when most of the name matched, or its first word did
        // ("butter" alone only matches the end of "Peanut butter").
        bestConfident =
            matched / nameWords.length > 0.5 ||
            query.any((q) => q == nameWords.first || (q.length >= 4 && nameWords.first.startsWith(q)));
      }
    }
    if (best == null || bestScore < 0.5) return null;
    return (food: best, confident: bestConfident);
  }

  ParsedFood _withAmount(
    String phrase,
    FoodItem food,
    double? amount,
    _Unit? unit,
    String? size, {
    bool confident = true,
  }) {
    final p = _rawAmount(phrase, food, amount, unit, size);
    return confident
        ? p
        : ParsedFood(
            phrase: p.phrase,
            food: p.food,
            serving: p.serving,
            count: p.count,
            servingEstimated: p.servingEstimated,
            confident: false,
          );
  }

  ParsedFood _rawAmount(String phrase, FoodItem food, double? amount, _Unit? unit, String? size) {
    final n = amount ?? 1;
    final base = food.baseUnit;

    // Weights and volumes go straight into grams or millilitres.
    switch (unit) {
      case _Unit.gram:
      case _Unit.ml:
        return ParsedFood(phrase: phrase, food: food, count: n);
      case _Unit.kg:
      case _Unit.litre:
        return ParsedFood(phrase: phrase, food: food, count: n * 1000);
      default:
        break;
    }

    if (unit != null && unit != _Unit.piece) {
      final serving = _servingForUnit(food, unit, size);
      if (serving != null) return ParsedFood(phrase: phrase, food: food, serving: serving, count: n);
      final grams = _householdSize(unit, base);
      return ParsedFood(
        phrase: phrase,
        food: food,
        serving: FoodServing(label: '1 ${_unitName(unit)} (${grams.round()} $base)', quantity: grams),
        count: n,
        servingEstimated: true,
      );
    }

    // No unit (or "piece"): the food's own serving, e.g. "1 medium roti".
    if (food.servings.isEmpty) {
      // A bare large number is a weight ("200 paneer"); otherwise 100 g each.
      if (amount != null && amount >= 10) return ParsedFood(phrase: phrase, food: food, count: amount);
      return ParsedFood(phrase: phrase, food: food, count: n * food.baseQuantity);
    }
    return ParsedFood(phrase: phrase, food: food, serving: _defaultServing(food, size), count: n);
  }

  FoodServing? _servingForUnit(FoodItem food, _Unit unit, String? size) {
    for (final word in _unitLabelWords[unit] ?? const <String>[]) {
      final candidates = food.servings.where((s) => s.label.toLowerCase().contains(word)).toList();
      if (candidates.isEmpty) continue;
      if (size != null) {
        final sized = candidates.where((s) => s.label.toLowerCase().contains(size));
        if (sized.isNotEmpty) return sized.first;
      }
      // Without a size, prefer the plain or medium serving over small/large.
      return candidates.firstWhere(
        (s) => !s.label.toLowerCase().contains('small') && !s.label.toLowerCase().contains('large'),
        orElse: () => candidates.first,
      );
    }
    return null;
  }

  FoodServing _defaultServing(FoodItem food, String? size) {
    final want = size ?? 'medium';
    return food.servings.firstWhere((s) => s.label.toLowerCase().contains(want), orElse: () => food.servings.first);
  }
}
