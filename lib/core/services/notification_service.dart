import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications for reminders and the rest timer. Everything stays on
/// the device; nothing is sent anywhere.
abstract class NotificationService {
  Future<void> init();

  /// Asks for permission on Android 13+. Returns whether notifications are allowed.
  Future<bool> requestPermission();
  Future<bool> areEnabled();
  Future<bool> canScheduleExact();
  Future<void> requestExactAlarms();

  Future<void> scheduleOnce({required int id, required DateTime at, required String title, required String body});
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  });
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
  });
  Future<void> cancel(int id);
  Future<void> cancelAll();
}

/// Notification ids are grouped by purpose so a group can be cleared.
class NotificationIds {
  static const restTimer = 900;
  static int workout(int weekday) => 100 + weekday;
  static const meal = 200;
  static int water(int slot) => 300 + slot;
  static const waterSlots = 24;
  static const weight = 400;
}

class LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _remindersChannel = AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Workout, meal, water and weigh-in reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const _restChannel = AndroidNotificationDetails(
    'rest_timer',
    'Rest timer',
    channelDescription: 'Tells you when your rest between sets is over',
    importance: Importance.high,
    priority: Priority.high,
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      await _setLocalTimezone();
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_notification')),
      );
      _ready = true;
    } catch (e, st) {
      // Notifications are optional; the app works without them.
      debugPrint('Notifications unavailable: $e\n$st');
    }
  }

  Future<void> _setLocalTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      return;
    } catch (e) {
      debugPrint('Could not read the device timezone ($e); matching by UTC offset.');
    }
    // Fall back to any zone with the device's current offset so reminder
    // times are still right today.
    final offset = DateTime.now().timeZoneOffset;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (location.timeZone(now).offset == offset) {
        tz.setLocalLocation(location);
        return;
      }
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    return await _android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<bool> areEnabled() async {
    if (!_ready) return false;
    return await _android?.areNotificationsEnabled() ?? true;
  }

  @override
  Future<bool> canScheduleExact() async {
    if (!_ready) return false;
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> requestExactAlarms() async {
    if (!_ready) return;
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> scheduleOnce({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    final exact = await canScheduleExact();
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(android: _restChannel),
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
    );
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: _nextInstance(hour, minute),
      notificationDetails: const NotificationDetails(android: _remindersChannel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    var at = _nextInstance(hour, minute);
    while (at.weekday != weekday) {
      at = at.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: at,
      notificationDetails: const NotificationDetails(android: _remindersChannel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  @override
  Future<void> cancel(int id) async {
    if (!_ready) return;
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }
}

/// Used in tests and when the platform has no notification support.
class NoopNotificationService implements NotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<bool> areEnabled() async => false;
  @override
  Future<bool> canScheduleExact() async => false;
  @override
  Future<void> requestExactAlarms() async {}
  @override
  Future<void> scheduleOnce({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {}
}

final notificationServiceProvider = Provider<NotificationService>((ref) => NoopNotificationService());
