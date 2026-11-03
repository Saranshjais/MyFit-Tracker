import 'dart:convert';

import 'package:flutter/services.dart';

/// First-launch data bundled in `assets/data/`. Kept out of the Dart code so
/// nutrition values can be reviewed and corrected without touching the UI.
class SeedData {
  const SeedData({required this.exercises, required this.foods, required this.foodSources});

  final List<Map<String, dynamic>> exercises;
  final List<Map<String, dynamic>> foods;

  /// Source key ("usda", "home", …) → human-readable provenance.
  final Map<String, String> foodSources;

  static const exercisesAsset = 'assets/data/exercises.json';
  static const foodsAsset = 'assets/data/foods.json';

  static Future<SeedData> fromBundle(AssetBundle bundle) async =>
      SeedData.fromJson(await bundle.loadString(exercisesAsset), await bundle.loadString(foodsAsset));

  factory SeedData.fromJson(String exercisesJson, String foodsJson) {
    final exercises = (jsonDecode(exercisesJson) as List).cast<Map<String, dynamic>>();
    final foodsDoc = jsonDecode(foodsJson) as Map<String, dynamic>;
    return SeedData(
      exercises: exercises,
      foods: (foodsDoc['foods'] as List).cast<Map<String, dynamic>>(),
      foodSources: (foodsDoc['sources'] as Map).cast<String, String>(),
    );
  }
}
