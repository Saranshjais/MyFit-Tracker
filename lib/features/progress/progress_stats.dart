import '../../core/utils/dates.dart';
import 'body_repository.dart';

/// Weight figures calculated only from logged entries. Missing days are left
/// out, never filled in.
class WeightStats {
  const WeightStats({
    this.latest,
    this.periodFirst,
    this.periodChangeKg,
    this.weeklyAverageKg,
    this.weeklyAverageCount = 0,
    this.entriesInPeriod = const [],
  });

  final WeightLog? latest;

  /// Earliest entry inside the selected period.
  final WeightLog? periodFirst;

  /// Latest minus earliest entry in the period (null with fewer than two).
  final double? periodChangeKg;

  /// Mean of entries in the 7 days ending on the latest entry's date.
  final double? weeklyAverageKg;
  final int weeklyAverageCount;
  final List<WeightLog> entriesInPeriod;
}

/// [logs] must be sorted oldest first. [periodDays] null means all time.
WeightStats weightStats(List<WeightLog> logs, {required DateTime today, int? periodDays}) {
  if (logs.isEmpty) return const WeightStats();
  final fromKey = periodDays == null ? null : dateKey(addDays(today, 1 - periodDays));
  final inPeriod = fromKey == null ? logs : logs.where((l) => l.date.compareTo(fromKey) >= 0).toList();
  final latest = logs.last;

  final weekStart = dateKey(addDays(parseDateKey(latest.date), -6));
  final week = logs.where((l) => l.date.compareTo(weekStart) >= 0 && l.date.compareTo(latest.date) <= 0).toList();
  final avg = week.isEmpty ? null : week.fold<double>(0, (s, l) => s + l.weightKg) / week.length;

  return WeightStats(
    latest: latest,
    periodFirst: inPeriod.isEmpty ? null : inPeriod.first,
    periodChangeKg: inPeriod.length < 2 ? null : inPeriod.last.weightKg - inPeriod.first.weightKg,
    weeklyAverageKg: avg,
    weeklyAverageCount: week.length,
    entriesInPeriod: inPeriod,
  );
}

/// Latest value of each measurement type, newest first.
Map<String, Measurement> latestMeasurements(List<Measurement> all) {
  final result = <String, Measurement>{};
  for (final m in all) {
    final existing = result[m.type];
    if (existing == null || m.date.compareTo(existing.date) > 0) result[m.type] = m;
  }
  return result;
}
