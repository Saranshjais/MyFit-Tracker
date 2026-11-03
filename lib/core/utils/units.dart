import 'dart:math' as math;

import 'format.dart';

/// Values are stored in canonical units (kg, cm, ml) and converted only for
/// display or when parsing user input. Never store a converted value.

enum WeightUnit {
  kg('kg'),
  lb('lb');

  const WeightUnit(this.label);
  final String label;
}

enum LengthUnit {
  cm('cm'),
  ftIn('ft / in');

  const LengthUnit(this.label);
  final String label;
}

enum WaterUnit {
  ml('ml'),
  flOz('fl oz');

  const WaterUnit(this.label);
  final String label;
}

const double kgPerLb = 0.45359237;
const double cmPerInch = 2.54;
const double mlPerFlOz = 29.5735295625;

double kgToLb(double kg) => kg / kgPerLb;
double lbToKg(double lb) => lb * kgPerLb;
double cmToInches(double cm) => cm / cmPerInch;
double inchesToCm(double inches) => inches * cmPerInch;
double mlToFlOz(double ml) => ml / mlPerFlOz;
double flOzToMl(double flOz) => flOz * mlPerFlOz;

double ftInToCm(int feet, double inches) => inchesToCm(feet * 12 + inches);

/// Splits a height into whole feet and inches rounded to [inchDecimals].
({int feet, double inches}) cmToFtIn(double cm, {int inchDecimals = 0}) {
  final totalInches = cmToInches(cm);
  var feet = totalInches ~/ 12;
  final factor = math.pow(10, inchDecimals);
  var inches = ((totalInches - feet * 12) * factor).round() / factor;
  if (inches >= 12) {
    feet += 1;
    inches -= 12;
  }
  return (feet: feet, inches: inches);
}

/// Weight in the display unit.
double weightForDisplay(double kg, WeightUnit unit) => unit == WeightUnit.kg ? kg : kgToLb(kg);

/// Converts a value typed in [unit] back to kg for storage.
double weightToKg(double value, WeightUnit unit) => unit == WeightUnit.kg ? value : lbToKg(value);

String formatWeight(double kg, WeightUnit unit, {int decimals = 1}) =>
    '${formatNumber(weightForDisplay(kg, unit), decimals: decimals)} ${unit.label}';

/// Signed weight change, e.g. "+1.8 kg".
String formatWeightChange(double kgDelta, WeightUnit unit) {
  final v = weightForDisplay(kgDelta.abs(), unit);
  final sign = kgDelta > 0.0001 ? '+' : (kgDelta < -0.0001 ? '−' : '');
  return '$sign${formatNumber(v, decimals: 1)} ${unit.label}';
}

String formatHeight(double cm, LengthUnit unit) {
  if (unit == LengthUnit.cm) return '${formatNumber(cm, decimals: 0)} cm';
  final ftIn = cmToFtIn(cm);
  return "${ftIn.feet}′ ${ftIn.inches.toInt()}″";
}

/// Body measurements: cm or inches.
double lengthForDisplay(double cm, LengthUnit unit) => unit == LengthUnit.cm ? cm : cmToInches(cm);
double lengthToCm(double value, LengthUnit unit) => unit == LengthUnit.cm ? value : inchesToCm(value);
String lengthUnitLabel(LengthUnit unit) => unit == LengthUnit.cm ? 'cm' : 'in';
String formatLength(double cm, LengthUnit unit) =>
    '${formatNumber(lengthForDisplay(cm, unit), decimals: 1)} ${lengthUnitLabel(unit)}';

double waterForDisplay(double ml, WaterUnit unit) => unit == WaterUnit.ml ? ml : mlToFlOz(ml);
double waterToMl(double value, WaterUnit unit) => unit == WaterUnit.ml ? value : flOzToMl(value);
String formatWater(double ml, WaterUnit unit) =>
    unit == WaterUnit.ml ? '${formatThousands(ml)} ml' : '${formatNumber(mlToFlOz(ml), decimals: 1)} fl oz';
