import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'core/providers/core_providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'features/reminders/reminders.dart';
import 'features/settings/app_settings.dart';
import 'features/workout/rest_timer.dart';
import 'features/workout/workout_providers.dart';

class MyFitApp extends ConsumerStatefulWidget {
  const MyFitApp({super.key});

  @override
  ConsumerState<MyFitApp> createState() => _MyFitAppState();
}

class _MyFitAppState extends ConsumerState<MyFitApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ref.read(todayProvider.notifier).refresh();
        ref.read(restTimerProvider.notifier).onAppResumed();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        ref.read(restTimerProvider.notifier).onAppPaused();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep workout reminders in step with the active plan's training days.
    ref.listen(activePlanProvider, (previous, next) {
      if (next.hasValue) ref.read(reminderSyncProvider).syncIfEnabled();
    });
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: buildTheme(AppPalette.light, Brightness.light),
      darkTheme: buildTheme(AppPalette.dark, Brightness.dark),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
