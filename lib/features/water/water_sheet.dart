import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/feedback.dart';
import '../profile/user_profile.dart';
import '../settings/app_settings.dart';
import 'water_repository.dart';

Future<void> showWaterSheet(BuildContext context, {required String date}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => WaterSheet(date: date),
);

class WaterSheet extends ConsumerWidget {
  const WaterSheet({super.key, required this.date});
  final String date;

  Future<void> _add(BuildContext context, WidgetRef ref, double ml) async {
    await runGuarded(context, () async {
      await ref.read(waterRepositoryProvider).add(date, ml);
      ref.read(nutritionRevisionProvider.notifier).bump();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);
    final target = ref.watch(profileProvider.select((pr) => pr.waterTargetMl));
    final logs = ref.watch(waterForDateProvider(date)).value ?? const <WaterLog>[];
    final total = logs.fold<double>(0, (s, l) => s + l.ml);
    final unit = settings.waterUnit;
    final today = ref.watch(todayProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Water · ${relativeDayLabel(parseDateKey(date), today)}', style: t.titleLarge),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatWater(total, unit), style: t.headlineSmall?.copyWith(color: p.water)),
                const SizedBox(width: 8),
                if (target != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('of ${formatWater(target, unit)}', style: t.bodySmall),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (target != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: (total / target).clamp(0, 1), minHeight: 6, color: p.water),
              )
            else
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/more/profile');
                },
                child: const Text('Set a daily water target'),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _add(context, ref, settings.glassSizeMl),
                    icon: const Icon(Icons.local_drink),
                    label: Text('Glass (${formatWater(settings.glassSizeMl, unit)})'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    final value = await showNumberInputDialog(
                      context,
                      title: 'Add water',
                      label: 'Amount',
                      suffix: unit.label,
                      max: unit == WaterUnit.ml ? 5000 : 170,
                    );
                    if (value != null && context.mounted) await _add(context, ref, waterToMl(value, unit));
                  },
                  child: const Text('Custom'),
                ),
              ],
            ),
            if (logs.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Entries', style: t.titleSmall),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in logs.reversed)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.water_drop, color: p.water, size: 20),
                        title: Text(formatWater(l.ml, unit)),
                        subtitle: Text(formatTime(l.loggedAt)),
                        trailing: IconButton(
                          tooltip: 'Remove entry',
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () async {
                            await ref.read(waterRepositoryProvider).delete(l.id);
                            ref.read(nutritionRevisionProvider.notifier).bump();
                            if (context.mounted) {
                              showSnack(
                                context,
                                'Removed ${formatWater(l.ml, unit)}',
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () async {
                                    await ref.read(waterRepositoryProvider).add(date, l.ml);
                                    ref.read(nutritionRevisionProvider.notifier).bump();
                                  },
                                ),
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
