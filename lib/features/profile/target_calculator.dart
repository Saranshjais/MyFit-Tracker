import 'dart:math' as math;

import 'user_profile.dart';

/// Daily calorie and macro estimate with the numbers behind it, so the
/// profile screen can explain how the target was reached.
class TargetEstimate {
  const TargetEstimate({
    required this.bmr,
    required this.tdee,
    required this.adjustment,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.proteinPerKg,
    required this.flooredAtMinimum,
  });

  /// Basal metabolic rate (Mifflin–St Jeor), kcal/day.
  final double bmr;

  /// Estimated maintenance: BMR × activity multiplier.
  final double tdee;

  /// Goal-based change applied to maintenance, kcal/day.
  final double adjustment;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double proteinPerKg;

  /// True when a fat-loss target was raised to the safety floor.
  final bool flooredAtMinimum;
}

class TargetInputs {
  const TargetInputs({this.age, this.sex, this.heightCm, this.weightKg, this.activity, this.goal});
  final int? age;
  final Sex? sex;
  final double? heightCm;
  final double? weightKg;
  final ActivityLevel? activity;
  final FitnessGoal? goal;
}

/// Calorie targets use the Mifflin–St Jeor equation:
///   men:   BMR = 10 × kg + 6.25 × cm − 5 × age + 5
///   women: BMR = 10 × kg + 6.25 × cm − 5 × age − 161
/// Maintenance (TDEE) = BMR × activity multiplier. Both are estimates; real
/// needs vary, so the result is a starting point to review against several
/// weeks of weight data, not medical advice.
class TargetCalculator {
  /// Minimum daily calories the app will suggest for a deficit.
  static const minimumCalories = 1200.0;

  /// Lists the inputs still needed for an individual estimate.
  static List<String> missingInputs(TargetInputs i) => [
    if (i.age == null) 'age',
    if (i.sex == null) 'sex (used by the formula)',
    if (i.heightCm == null) 'height',
    if (i.weightKg == null) 'current weight',
    if (i.activity == null) 'activity level',
    if (i.goal == null) 'goal',
  ];

  static double bmr({required double weightKg, required double heightCm, required int age, required Sex sex}) =>
      10 * weightKg + 6.25 * heightCm - 5 * age + (sex == Sex.male ? 5 : -161);

  /// Conservative goal adjustment relative to maintenance.
  static double goalAdjustment(FitnessGoal goal, double tdee) => switch (goal) {
    FitnessGoal.muscleGain => math.min(0.10 * tdee, 350.0),
    FitnessGoal.leanMuscleGain => math.min(0.05 * tdee, 200.0),
    FitnessGoal.strength => math.min(0.05 * tdee, 200.0),
    FitnessGoal.fatLoss => -math.min(0.20 * tdee, 500.0),
    FitnessGoal.recomposition => 0.0,
    FitnessGoal.generalFitness => 0.0,
  };

  /// Protein in g per kg of body weight, within the commonly cited
  /// 1.4–2.2 g/kg range for people who train.
  static double proteinPerKg(FitnessGoal goal) => switch (goal) {
    FitnessGoal.fatLoss || FitnessGoal.recomposition => 2.0,
    FitnessGoal.muscleGain || FitnessGoal.leanMuscleGain || FitnessGoal.strength => 1.8,
    FitnessGoal.generalFitness => 1.4,
  };

  /// Returns null when any required input is missing.
  static TargetEstimate? estimate(TargetInputs i) {
    if (missingInputs(i).isNotEmpty) return null;
    final base = bmr(weightKg: i.weightKg!, heightCm: i.heightCm!, age: i.age!, sex: i.sex!);
    final tdee = base * i.activity!.multiplier;
    final adjustment = goalAdjustment(i.goal!, tdee);
    var calories = tdee + adjustment;
    var floored = false;
    final floor = math.max(minimumCalories, base);
    if (adjustment < 0 && calories < floor) {
      calories = floor;
      floored = true;
    }
    calories = (calories / 10).round() * 10.0;

    final perKg = proteinPerKg(i.goal!);
    // Protein is capped at 35% of calories so very low budgets stay balanced.
    final protein = math.min(perKg * i.weightKg!, 0.35 * calories / 4).roundToDouble();
    final fat = (0.25 * calories / 9).roundToDouble();
    final carbs = math.max(0, (calories - protein * 4 - fat * 9) / 4).roundToDouble();

    return TargetEstimate(
      bmr: base,
      tdee: tdee,
      adjustment: calories - tdee,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      proteinPerKg: perKg,
      flooredAtMinimum: floored,
    );
  }
}
