import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../settings/app_settings.dart';
import '../workout_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final unit = ref.watch(settingsProvider).weightUnit;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Workout history')),
      body: AsyncView(
        value: history,
        builder: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No workouts yet',
              message: 'Finished workouts appear here with their sets and volume.',
            );
          }
          final month = DateFormat('MMMM y');
          return ListView.builder(
            padding: pagePadding,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final s = items[i];
              final date = parseDateKey(s.date);
              final showHeader = i == 0 || month.format(parseDateKey(items[i - 1].date)) != month.format(date);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader)
                    SectionTitle(month.format(date), padding: EdgeInsets.only(top: i == 0 ? 4 : 18, bottom: 8)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => context.go('/workout/history/${s.id}'),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: context.palette.accentSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Text('${date.day}', style: t.titleMedium?.copyWith(color: context.palette.accentText)),
                                Text(weekdayShort(date.weekday), style: t.bodySmall?.copyWith(fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: t.titleSmall),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    '${s.exerciseCount} exercises',
                                    '${s.setCount} sets',
                                    if (s.volumeKg > 0) formatWeight(s.volumeKg, unit, decimals: 0),
                                    if (s.durationSeconds > 0)
                                      formatDurationShort(Duration(seconds: s.durationSeconds)),
                                  ].join(' · '),
                                  style: t.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: context.palette.textMuted),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
