import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/notification_service.dart';
import '../profile/user_profile.dart';
import '../reminders/reminders.dart';
import '../workout/rest_timer.dart';
import 'app_settings.dart';

/// Refreshes every screen after the whole database changed (restore or reset).
Future<void> reloadAfterDataChange(WidgetRef ref) async {
  ref.read(restTimerProvider.notifier).reset();
  await ref.read(profileProvider.notifier).reload();
  ref.read(workoutRevisionProvider.notifier).bump();
  ref.read(nutritionRevisionProvider.notifier).bump();
  ref.read(bodyRevisionProvider.notifier).bump();
  ref.invalidate(remindersProvider);
  await ref.read(notificationServiceProvider).cancelAll();
  await ref.read(reminderSyncProvider).sync();
  // Last: may redirect to onboarding after a reset.
  await ref.read(settingsProvider.notifier).reload();
}
