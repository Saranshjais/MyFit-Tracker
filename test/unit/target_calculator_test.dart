import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/features/profile/target_calculator.dart';
import 'package:myfit_tracker/features/profile/user_profile.dart';

void main() {
  const complete = TargetInputs(
    age: 22,
    sex: Sex.male,
    heightCm: 183,
    weightKg: 64,
    activity: ActivityLevel.moderate,
    goal: FitnessGoal.muscleGain,
  );

  test('Mifflin–St Jeor BMR', () {
    // 10 × 64 + 6.25 × 183 − 5 × 22 + 5 = 1678.75
    expect(TargetCalculator.bmr(weightKg: 64, heightCm: 183, age: 22, sex: Sex.male), closeTo(1678.75, 1e-9));
    // Same person, female constant (−161): 1512.75
    expect(TargetCalculator.bmr(weightKg: 64, heightCm: 183, age: 22, sex: Sex.female), closeTo(1512.75, 1e-9));
  });

  test('estimate uses activity and a conservative surplus for muscle gain', () {
    final e = TargetCalculator.estimate(complete)!;
    expect(e.tdee, closeTo(1678.75 * 1.55, 1e-6));
    // Surplus is min(10% of TDEE, 350 kcal) = ~260 kcal.
    expect(e.calories, closeTo(((1678.75 * 1.55 * 1.10) / 10).round() * 10, 1e-9));
    expect(e.protein, closeTo(1.8 * 64, 1));
    // Macros add up to the calorie target (within rounding).
    expect(e.protein * 4 + e.carbs * 4 + e.fat * 9, closeTo(e.calories, 10));
  });

  test('fat loss never goes below the safety floor', () {
    const small = TargetInputs(
      age: 60,
      sex: Sex.female,
      heightCm: 150,
      weightKg: 45,
      activity: ActivityLevel.sedentary,
      goal: FitnessGoal.fatLoss,
    );
    final e = TargetCalculator.estimate(small)!;
    expect(e.calories, greaterThanOrEqualTo(TargetCalculator.minimumCalories));
    expect(e.calories, greaterThanOrEqualTo(e.bmr - 10));
    expect(e.flooredAtMinimum, isTrue);
  });

  test('missing inputs are reported instead of guessing', () {
    const partial = TargetInputs(age: 30, weightKg: 70, goal: FitnessGoal.strength);
    expect(TargetCalculator.estimate(partial), isNull);
    final missing = TargetCalculator.missingInputs(partial);
    expect(missing, contains('height'));
    expect(missing, contains('activity level'));
    expect(missing.any((m) => m.startsWith('sex')), isTrue);
  });

  test('maintenance goals do not change calories', () {
    const recomposition = TargetInputs(
      age: 30,
      sex: Sex.female,
      heightCm: 165,
      weightKg: 60,
      activity: ActivityLevel.light,
      goal: FitnessGoal.recomposition,
    );
    final e = TargetCalculator.estimate(recomposition)!;
    expect(e.calories, closeTo((e.tdee / 10).round() * 10, 1e-9));
  });
}
