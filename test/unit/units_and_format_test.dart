import 'package:flutter_test/flutter_test.dart';
import 'package:myfit_tracker/core/utils/dates.dart';
import 'package:myfit_tracker/core/utils/format.dart';
import 'package:myfit_tracker/core/utils/units.dart';

void main() {
  group('weight', () {
    test('kg and lb convert both ways', () {
      expect(kgToLb(100), closeTo(220.462, 0.001));
      expect(lbToKg(220.462), closeTo(100, 0.001));
      expect(weightToKg(weightForDisplay(64.2, WeightUnit.lb), WeightUnit.lb), closeTo(64.2, 1e-9));
    });

    test('kg display is not converted', () {
      expect(weightForDisplay(64.2, WeightUnit.kg), 64.2);
      expect(formatWeight(64.2, WeightUnit.kg), '64.2 kg');
    });

    test('weight change keeps its sign', () {
      expect(formatWeightChange(1.8, WeightUnit.kg), '+1.8 kg');
      expect(formatWeightChange(-0.5, WeightUnit.kg), '−0.5 kg');
      expect(formatWeightChange(0, WeightUnit.kg), '0 kg');
    });
  });

  group('height', () {
    test('183 cm is 6 ft 0 in', () {
      final h = cmToFtIn(183);
      expect(h.feet, 6);
      expect(h.inches, 0);
    });

    test('feet and inches convert back to cm', () {
      expect(ftInToCm(5, 11), closeTo(180.34, 0.01));
    });

    test('rounding never produces 12 inches', () {
      final h = cmToFtIn(182.8); // 71.97 in
      expect(h.feet, 6);
      expect(h.inches, 0);
    });
  });

  test('water converts ml and fl oz', () {
    expect(mlToFlOz(29.5735295625), closeTo(1, 1e-9));
    expect(waterToMl(8, WaterUnit.flOz), closeTo(236.588, 0.001));
  });

  group('number input', () {
    test('accepts comma as decimal separator', () {
      expect(parseDecimal('22,5'), 22.5);
      expect(parseDecimal(' 40 '), 40);
    });

    test('rejects invalid input', () {
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('abc'), isNull);
      expect(parseDecimal('1.2.3'), isNull);
    });

    test('display rounding drops trailing zeros', () {
      expect(formatNumber(20.0), '20');
      expect(formatNumber(22.50, decimals: 2), '22.5');
      expect(formatThousands(1850.4), '1,850');
    });

    test('validators reject negative values', () {
      expect(validateRequiredNumber('-5'), isNotNull);
      expect(validateRequiredNumber('5'), isNull);
      expect(validateOptionalNumber(''), isNull);
      expect(validateRequiredNumber('0', allowZero: false), isNotNull);
    });
  });

  group('dates', () {
    test('date keys round-trip', () {
      final d = DateTime(2026, 3, 9);
      expect(dateKey(d), '2026-03-09');
      expect(parseDateKey('2026-03-09'), d);
    });

    test('week starts on Monday', () {
      expect(startOfWeek(DateTime(2026, 11, 5)), DateTime(2026, 11, 2)); // Thursday → Monday
      expect(startOfWeek(DateTime(2026, 11, 8)), DateTime(2026, 11, 2)); // Sunday → Monday
    });

    test('adding days keeps calendar dates', () {
      expect(addDays(DateTime(2026, 2, 28), 1), DateTime(2026, 3, 1));
    });
  });
}
