import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/cards.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final sources = ref.watch(databaseProvider).seed.foodSources;

    Widget block(String title, List<String> lines) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.titleSmall),
            const SizedBox(height: 8),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(l, style: t.bodyMedium?.copyWith(color: p.textSecondary, height: 1.4)),
              ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: pagePadding,
        children: [
          Row(
            children: [
              IconTile(icon: Icons.fitness_center, size: 56),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppInfo.name, style: t.titleLarge),
                  Text('Version ${AppInfo.version}', style: t.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          block('Privacy', const [
            'Everything you enter is stored only on this phone. There is no account, no advertising, no analytics and no internet connection required.',
            'The microphone is used only while you tap Speak on the "Speak or type a meal" screen. '
                "Your phone's speech service turns it into text (it may use Google's servers unless offline speech is installed). "
                'Typing works fully on the phone.',
            'Uninstalling the app deletes its data. Use Backup & Restore to keep a copy.',
          ]),
          block('Nutrition data', [
            'Values are per 100 g or 100 ml and come from these sources:',
            for (final s in sources.values) '• $s',
            'Home-style dishes and household serving sizes are estimates. Totals are approximate, especially when ingredients or oil are unknown.',
          ]),
          block('How numbers are calculated', const [
            'Food: nutrient per 100 g × grams eaten ÷ 100. Each diary entry stores the values used at the time.',
            'Calorie targets: Mifflin–St Jeor resting energy × an activity multiplier, adjusted conservatively for your goal. Protein 1.4–2.0 g per kg; fat about 25% of calories.',
            'Volume: weight × reps of completed sets with external load. Bodyweight-only, timed and distance sets are not counted.',
            'Estimated 1RM: Epley formula, weight × (1 + reps ÷ 30), for sets of 1–12 reps. Always an estimate.',
          ]),
          block('Not medical advice', const [
            'MyFit Tracker is a personal logging tool. Its estimates are not medical or dietary advice. '
                'Talk to a qualified professional before major changes to diet or training, especially with a health condition.',
          ]),
          OutlinedButton(
            onPressed: () =>
                showLicensePage(context: context, applicationName: AppInfo.name, applicationVersion: AppInfo.version),
            child: const Text('Open-source licences'),
          ),
        ],
      ),
    );
  }
}
