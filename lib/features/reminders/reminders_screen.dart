import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notification_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import 'reminders.dart';

final _permissionProvider = FutureProvider.autoDispose<({bool enabled, bool exact})>((ref) async {
  final n = ref.watch(notificationServiceProvider);
  return (enabled: await n.areEnabled(), exact: await n.canScheduleExact());
});

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  Future<void> _update(BuildContext context, WidgetRef ref, ReminderSetting next) async {
    if (next.enabled) {
      final allowed = await ref.read(notificationServiceProvider).requestPermission();
      if (!allowed) {
        if (context.mounted) {
          showSnack(
            context,
            'Notifications are turned off for MyFit Tracker. Allow them in Android settings to get reminders.',
          );
        }
        ref.invalidate(_permissionProvider);
        return;
      }
    }
    await ref.read(reminderRepositoryProvider).save(next);
    ref.invalidate(remindersProvider);
    ref.invalidate(_permissionProvider);
    await ref.read(reminderSyncProvider).sync();
  }

  String _time(BuildContext context, int h, int m) => TimeOfDay(hour: h, minute: m).format(context);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final reminders = ref.watch(remindersProvider);
    final permission = ref.watch(_permissionProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: AsyncView(
        value: reminders,
        builder: (list) => ListView(
          padding: pagePadding,
          children: [
            Text(
              'All reminders are optional and run on this phone. Turn any of them off at any time.',
              style: t.bodySmall,
            ),
            const SizedBox(height: 12),
            if (permission != null && !permission.enabled && list.any((r) => r.enabled))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  color: p.warning.withValues(alpha: 0.12),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_off_outlined, color: p.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Notifications are blocked, so reminders cannot appear.', style: t.bodySmall),
                      ),
                      TextButton(
                        onPressed: () async {
                          await ref.read(notificationServiceProvider).requestPermission();
                          ref.invalidate(_permissionProvider);
                        },
                        child: const Text('Allow'),
                      ),
                    ],
                  ),
                ),
              ),
            for (final r in list) ...[
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(r.type.label),
                      subtitle: Text(r.type.description),
                      value: r.enabled,
                      onChanged: (v) => _update(context, ref, r.copyWith(enabled: v)),
                    ),
                    if (r.enabled) ...[
                      Divider(height: 1, color: p.border),
                      ListTile(
                        title: Text(r.type == ReminderType.water ? 'From' : 'Time'),
                        trailing: Text(
                          _time(context, r.hour, r.minute),
                          style: t.titleSmall?.copyWith(color: p.accentText),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: r.hour, minute: r.minute),
                          );
                          if (picked != null && context.mounted) {
                            // Keep the water window valid when the start moves past its end.
                            await _update(
                              context,
                              ref,
                              r.copyWith(
                                hour: picked.hour,
                                minute: picked.minute,
                                endHour: math.max(r.endHour, picked.hour),
                              ),
                            );
                          }
                        },
                      ),
                      if (r.type == ReminderType.water)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: LabeledDropdown<int>(
                                  label: 'Every',
                                  value: r.intervalHours,
                                  items: const [1, 2, 3, 4],
                                  itemLabel: (h) => '$h ${h == 1 ? 'hour' : 'hours'}',
                                  onChanged: (h) => _update(context, ref, r.copyWith(intervalHours: h)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: LabeledDropdown<int>(
                                  label: 'Until',
                                  value: r.endHour.clamp(r.hour, 23),
                                  items: [for (var h = r.hour; h <= 23; h++) h],
                                  itemLabel: (h) => _time(context, h, 0),
                                  onChanged: (h) => _update(context, ref, r.copyWith(endHour: h)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (r.type == ReminderType.workout)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text('Sent only on training days of your active plan.', style: t.bodySmall),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SectionTitle('Rest timer alert'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'When the app is in the background, a notification tells you your rest is over. '
                    'Android may delay it by up to a minute unless precise alarms are allowed.',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        permission?.exact == true ? Icons.check_circle : Icons.schedule,
                        color: permission?.exact == true ? p.accentText : p.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          permission?.exact == true ? 'Precise alarms allowed' : 'Precise alarms not allowed',
                          style: t.bodyMedium,
                        ),
                      ),
                      if (permission?.exact != true)
                        TextButton(
                          onPressed: () async {
                            await ref.read(notificationServiceProvider).requestExactAlarms();
                            ref.invalidate(_permissionProvider);
                          },
                          child: const Text('Allow'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
