import '../../core/utils/dates.dart';
import '../workout/models.dart';

enum DayStatus {
  completed('Workout completed'),
  inProgress('Workout in progress'),
  today('Planned for today'),
  planned('Planned'),
  missed('Planned, not logged'),
  rest('Rest day'),
  unplanned('Nothing planned');

  const DayStatus(this.description);
  final String description;
}

class DayActivity {
  const DayActivity({required this.date, required this.status});
  final DateTime date;
  final DayStatus status;
}

/// Status of each day Monday–Sunday of the week containing [today].
/// A completed session always wins; rest days are never "missed".
List<DayActivity> buildWeeklyActivity({
  required DateTime today,
  required PlanWithDays? plan,
  required Set<String> completedDates,
  String? inProgressDate,
}) {
  final monday = startOfWeek(today);
  final todayKey = dateKey(today);
  return [
    for (var i = 0; i < 7; i++)
      () {
        final date = addDays(monday, i);
        final key = dateKey(date);
        final DayStatus status;
        if (completedDates.contains(key)) {
          status = DayStatus.completed;
        } else if (key == inProgressDate) {
          status = DayStatus.inProgress;
        } else if (plan == null) {
          status = DayStatus.unplanned;
        } else if (plan.dayFor(date.weekday).isRestDay) {
          status = DayStatus.rest;
        } else {
          final cmp = key.compareTo(todayKey);
          status = cmp < 0 ? DayStatus.missed : (cmp == 0 ? DayStatus.today : DayStatus.planned);
        }
        return DayActivity(date: date, status: status);
      }(),
  ];
}
