import 'package:intl/intl.dart';

final _thousands = NumberFormat('#,##0');

/// Rounds for display and drops trailing zeros: 20.0 → "20", 22.50 → "22.5".
String formatNumber(double value, {int decimals = 1}) {
  if (value.isNaN || value.isInfinite) return '—';
  final fixed = value.toStringAsFixed(decimals);
  if (!fixed.contains('.')) return fixed;
  final trimmed = fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return trimmed == '-0' ? '0' : trimmed;
}

/// Whole number with thousands separators: 1850.4 → "1,850".
String formatThousands(double value) => _thousands.format(value.round());

String formatKcal(double kcal) => '${formatThousands(kcal)} kcal';

/// Grams for macros: one decimal below 10 g, whole grams above.
String formatGrams(double g) => '${formatNumber(g, decimals: g.abs() < 10 ? 1 : 0)} g';

/// Parses a decimal typed by the user, accepting "," as the decimal separator.
/// Returns null for empty or invalid input.
double? parseDecimal(String input) {
  final s = input.trim().replaceAll(',', '.');
  if (s.isEmpty) return null;
  final v = double.tryParse(s);
  if (v == null || v.isNaN || v.isInfinite) return null;
  return v;
}

int? parseInteger(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

/// Text-field value for an optional number without a pointless ".0".
String numberFieldText(double? value, {int decimals = 2}) =>
    value == null ? '' : formatNumber(value, decimals: decimals);

/// Validator helpers for forms. Each returns an error message or null.
String? validateRequiredNumber(
  String? input, {
  double min = 0,
  double? max,
  bool allowZero = true,
  String label = 'Value',
}) {
  final v = parseDecimal(input ?? '');
  if (v == null) return 'Enter a number';
  if (v < min || (!allowZero && v == 0)) {
    return '$label must be ${allowZero ? 'at least ${formatNumber(min)}' : 'greater than 0'}';
  }
  if (max != null && v > max) return '$label must be at most ${formatNumber(max)}';
  return null;
}

String? validateOptionalNumber(String? input, {double min = 0, double? max, String label = 'Value'}) {
  if ((input ?? '').trim().isEmpty) return null;
  return validateRequiredNumber(input, min: min, max: max, label: label);
}
