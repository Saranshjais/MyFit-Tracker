import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/notification_service.dart';
import '../workout/models.dart';
import '../workout/workout_providers.dart';

enum ReminderType {
  workout('Workout', 'On your planned training days'),
  meal('Meal logging', 'A daily nudge to log what you ate'),
  water('Water', 'Every few hours during the day'),
  weight('Weigh-in', 'A daily reminder to record your weight');

  const ReminderType(this.label, this.description);
  final String label;
  final String description;
}

@immutable
class ReminderSetting {
  const ReminderSetting({
    required this.type,
    required this.enabled,
    required this.hour,
    required this.minute,
    this.intervalHours = 2,
    this.endHour = 20,
  });

  final ReminderType type;
  final bool enabled;
  final int hour;
  final int minute;

  /// Water only: repeat every [intervalHours] from the start time until [endHour].
  final int intervalHours;
  final int endHour;

  factory ReminderSetting.fromMap(Map<String, Object?> m) {
    final config = m['configuration'] == null
        ? const <String, dynamic>{}
        : jsonDecode(m['configuration'] as String) as Map<String, dynamic>;
    return ReminderSetting(
      type: ReminderType.values.byName(m['reminder_type'] as String),
      enabled: m['enabled'] == 1,
      hour: m['hour'] as int,
      minute: m['minute'] as int,
      intervalHours: (config['intervalHours'] as int?) ?? 2,
      endHour: (config['endHour'] as int?) ?? 20,
    );
  }

  ReminderSetting copyWith({bool? enabled, int? hour, int? minute, int? intervalHours, int? endHour}) =>
      ReminderSetting(
        type: type,
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        intervalHours: intervalHours ?? this.intervalHours,
        endHour: endHour ?? this.endHour,
      );

  /// Times of day for the water reminder.
  List<({int hour, int minute})> get waterTimes {
    final times = <({int hour, int minute})>[];
    for (var h = hour; h <= endHour && times.length < NotificationIds.waterSlots; h += intervalHours.clamp(1, 12)) {
      times.add((hour: h, minute: minute));
    }
    return times;
  }
}

class ReminderRepository {
  ReminderRepository(this._db);
  final AppDatabase _db;

  Future<List<ReminderSetting>> all() async {
    final rows = await _db.db.query('reminder_settings', orderBy: 'id');
    final known = ReminderType.values.map((t) => t.name).toSet();
    return rows.where((r) => known.contains(r['reminder_type'])).map(ReminderSetting.fromMap).toList();
  }

  Future<void> save(ReminderSetting s) => _db.db.update(
    'reminder_settings',
    {
      'enabled': s.enabled ? 1 : 0,
      'hour': s.hour,
      'minute': s.minute,
      'configuration': s.type == ReminderType.water
          ? jsonEncode({'intervalHours': s.intervalHours, 'endHour': s.endHour})
          : null,
    },
    where: 'reminder_type = ?',
    whereArgs: [s.type.name],
  );
}

/// Turns reminder settings into scheduled notifications. Always clears the
/// old schedule first so changes never leave stale reminders behind.
class ReminderScheduler {
  ReminderScheduler(this._notifications);
  final NotificationService _notifications;

  Future<void> apply(List<ReminderSetting> settings, PlanWithDays? plan) async {
    for (var wd = 1; wd <= 7; wd++) {
      await _notifications.cancel(NotificationIds.workout(wd));
    }
    await _notifications.cancel(NotificationIds.meal);
    await _notifications.cancel(NotificationIds.weight);
    for (var i = 0; i < NotificationIds.waterSlots; i++) {
      await _notifications.cancel(NotificationIds.water(i));
    }

    for (final s in settings.where((s) => s.enabled)) {
      switch (s.type) {
        case ReminderType.workout:
          if (plan == null) continue;
          for (final day in plan.days.where((d) => !d.isRestDay)) {
            await _notifications.scheduleWeekly(
              id: NotificationIds.workout(day.weekday),
              weekday: day.weekday,
              hour: s.hour,
              minute: s.minute,
              title: 'Workout today: ${day.title}',
              body: day.exercises.isEmpty
                  ? 'Your training day is planned.'
                  : '${day.exercises.length} exercises planned. Ready when you are.',
            );
          }
        case ReminderType.meal:
          await _notifications.scheduleDaily(
            id: NotificationIds.meal,
            hour: s.hour,
            minute: s.minute,
            title: 'Log your meals',
            body: 'Add anything you have not logged yet today.',
          );
        case ReminderType.water:
          final times = s.waterTimes;
          for (var i = 0; i < times.length; i++) {
            await _notifications.scheduleDaily(
              id: NotificationIds.water(i),
              hour: times[i].hour,
              minute: times[i].minute,
              title: 'Water break',
              body: 'Have a glass of water and log it.',
            );
          }
        case ReminderType.weight:
          await _notifications.scheduleDaily(
            id: NotificationIds.weight,
            hour: s.hour,
            minute: s.minute,
            title: 'Weigh-in',
            body: 'Record your weight if you are weighing in today.',
          );
      }
    }
  }
}

final reminderRepositoryProvider = Provider((ref) => ReminderRepository(ref.watch(databaseProvider)));
final reminderSchedulerProvider = Provider((ref) => ReminderScheduler(ref.watch(notificationServiceProvider)));

final remindersProvider = FutureProvider<List<ReminderSetting>>((ref) {
  return ref.watch(reminderRepositoryProvider).all();
});

/// Re-applies the reminder schedule from the saved settings and active plan.
class ReminderSync {
  ReminderSync(this._ref);
  final Ref _ref;

  Future<void> sync() async {
    try {
      final settings = await _ref.read(reminderRepositoryProvider).all();
      final plan = await _ref.read(planRepositoryProvider).activePlan();
      await _ref.read(reminderSchedulerProvider).apply(settings, plan);
    } catch (e, st) {
      debugPrint('Could not schedule reminders: $e\n$st');
    }
  }

  /// Skips the work entirely when no reminder is switched on.
  Future<void> syncIfEnabled() async {
    final settings = await _ref.read(reminderRepositoryProvider).all();
    if (settings.any((s) => s.enabled)) await sync();
  }
}

final reminderSyncProvider = Provider((ref) => ReminderSync(ref));
