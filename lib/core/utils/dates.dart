import 'package:intl/intl.dart';

/// Local-date helpers. Logs are keyed by a local `YYYY-MM-DD` string so a
/// record always stays on the calendar day it was entered, whatever the
/// timezone or daylight-saving changes later.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _two(int v) => v.toString().padLeft(2, '0');

String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

DateTime parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) throw FormatException('Invalid date key', key);
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// Adds calendar days without drifting across daylight-saving changes.
DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) => addDays(dateOnly(d), 1 - d.weekday);

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

const weekdayShortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// [weekday] uses Dart's convention: 1 = Monday … 7 = Sunday.
String weekdayShort(int weekday) => weekdayShortNames[weekday - 1];
String weekdayName(int weekday) => weekdayNames[weekday - 1];

String formatLongDate(DateTime d) => DateFormat('EEEE, d MMMM').format(d);
String formatMediumDate(DateTime d) => DateFormat('EEE, d MMM y').format(d);
String formatShortDate(DateTime d) => DateFormat('d MMM').format(d);
String formatTime(DateTime d) => DateFormat('h:mm a').format(d);

/// "Today", "Yesterday", "Tomorrow" or a medium date, relative to [today].
String relativeDayLabel(DateTime day, DateTime today) {
  final diff = dateOnly(day).difference(dateOnly(today)).inDays;
  if (diff == 0) return 'Today';
  if (diff == -1) return 'Yesterday';
  if (diff == 1) return 'Tomorrow';
  return formatMediumDate(day);
}

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Good evening';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "1:05:09" or "05:09".
String formatClock(Duration d) {
  final total = d.inSeconds.abs();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
}

/// "1 h 5 min", "45 min", "40 s".
String formatDurationShort(Duration d) {
  final total = d.inSeconds;
  if (total < 60) return '$total s';
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Timestamps are stored as UTC ISO-8601 strings.
String timestampNow() => DateTime.now().toUtc().toIso8601String();
DateTime parseTimestamp(String s) => DateTime.parse(s).toLocal();
