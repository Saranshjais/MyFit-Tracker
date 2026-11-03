import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/feedback.dart';
import '../profile/user_profile.dart';
import 'app_settings.dart';
import 'data_actions.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _themeLabel(ThemeMode m) => switch (m) {
    ThemeMode.dark => 'Dark',
    ThemeMode.light => 'Light',
    ThemeMode.system => 'Match phone setting',
  };

  Future<void> _chooseTheme(BuildContext context, WidgetRef ref) async {
    final current = ref.read(settingsProvider).themeMode;
    final mode = await showChoiceSheet<ThemeMode>(
      context,
      title: 'Theme',
      selected: current,
      options: [
        (value: ThemeMode.dark, label: 'Dark', subtitle: 'Default', icon: Icons.dark_mode),
        (value: ThemeMode.light, label: 'Light', subtitle: null, icon: Icons.light_mode),
        (value: ThemeMode.system, label: 'Match phone setting', subtitle: null, icon: Icons.brightness_auto),
      ],
    );
    if (mode != null) await ref.read(settingsProvider.notifier).update((s) => s.copyWith(themeMode: mode));
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final first = await showConfirmDialog(
      context,
      title: 'Reset all data?',
      message:
          'This permanently deletes your profile, workouts, food diary, weight history, measurements and settings '
          'from this phone. It cannot be undone. Export a backup first if you might want them later.',
      confirm: 'Continue',
      destructive: true,
    );
    if (!first || !context.mounted) return;
    final typed = await showTextInputDialog(
      context,
      title: 'Type RESET to confirm',
      label: 'Type RESET',
      confirm: 'Delete everything',
      maxLength: 10,
    );
    if (typed?.toUpperCase() != 'RESET') {
      if (typed != null && context.mounted) showSnack(context, 'Nothing was deleted.');
      return;
    }
    await ref.read(databaseProvider).resetAllData();
    await reloadAfterDataChange(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider);
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: pagePadding,
          children: [
            const ScreenHeader(title: 'Settings & More'),
            AppCard(
              onTap: () => context.go('/more/profile'),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: p.accentSoft,
                    child: Text(
                      profile.initials,
                      style: TextStyle(color: p.accentText, fontWeight: FontWeight.w700, fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.name.isEmpty ? 'Your profile' : profile.name, style: t.titleMedium),
                        Text(profile.goal?.label ?? 'Set your goals and targets', style: t.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: p.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GroupCard(
              children: [
                NavRow(
                  icon: Icons.calendar_month,
                  color: const Color(0xFF5B8DEF),
                  title: 'Workout Plan',
                  subtitle: 'Manage your weekly plan',
                  onTap: () => context.go('/workout/plans'),
                ),
                NavRow(
                  icon: Icons.history,
                  color: const Color(0xFF5B8DEF),
                  title: 'Workout History',
                  subtitle: 'Past sessions and sets',
                  onTap: () => context.go('/workout/history'),
                ),
                NavRow(
                  icon: Icons.restaurant_menu,
                  color: p.accentText,
                  title: 'My Meals',
                  subtitle: 'Saved meals and recipes',
                  onTap: () => context.go('/diet/meals'),
                ),
                NavRow(
                  icon: Icons.menu_book,
                  color: const Color(0xFFF29A38),
                  title: 'Food Database',
                  subtitle: 'View and correct foods',
                  onTap: () => context.go('/diet/foods'),
                ),
                NavRow(
                  icon: Icons.straighten,
                  color: p.carbs,
                  title: 'Progress History',
                  subtitle: 'Weight and body measurements',
                  onTap: () => context.go('/progress/measurements'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GroupCard(
              children: [
                NavRow(
                  icon: Icons.notifications_active,
                  color: const Color(0xFFF26D5B),
                  title: 'Reminders',
                  subtitle: 'Workout, meals, water, weigh-in',
                  onTap: () => context.go('/more/reminders'),
                ),
                NavRow(
                  icon: Icons.square_foot,
                  color: const Color(0xFFB07CF2),
                  title: 'Units',
                  subtitle: '${settings.weightUnit.label} · ${settings.lengthUnit.label} · ${settings.waterUnit.label}',
                  onTap: () => context.go('/more/units'),
                ),
                NavRow(
                  icon: Icons.dark_mode,
                  color: p.textSecondary,
                  title: 'Theme',
                  subtitle: _themeLabel(settings.themeMode),
                  onTap: () => _chooseTheme(context, ref),
                ),
                NavRow(
                  icon: Icons.backup,
                  color: const Color(0xFF3FB8AF),
                  title: 'Backup & Restore',
                  subtitle: 'Keep your data safe',
                  onTap: () => context.go('/more/backup'),
                ),
                NavRow(
                  icon: Icons.info_outline,
                  color: const Color(0xFF5B8DEF),
                  title: 'About',
                  subtitle: 'Version, data sources, privacy',
                  onTap: () => context.go('/more/about'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _reset(context, ref),
              style: FilledButton.styleFrom(backgroundColor: p.error, foregroundColor: Colors.white),
              child: const Text('Reset All Data'),
            ),
          ],
        ),
      ),
    );
  }
}
