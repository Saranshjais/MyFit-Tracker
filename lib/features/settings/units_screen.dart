import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/dialogs.dart';
import 'app_settings.dart';

/// Values are always stored in kg, cm and ml; these only change display.
class UnitsScreen extends ConsumerWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final t = Theme.of(context).textTheme;

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.titleSmall),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Units & defaults')),
      body: ListView(
        padding: pagePadding,
        children: [
          section(
            'Weight',
            SegmentedButton<WeightUnit>(
              segments: const [
                ButtonSegment(value: WeightUnit.kg, label: Text('Kilograms (kg)')),
                ButtonSegment(value: WeightUnit.lb, label: Text('Pounds (lb)')),
              ],
              selected: {s.weightUnit},
              showSelectedIcon: false,
              onSelectionChanged: (v) => notifier.update((x) => x.copyWith(weightUnit: v.first)),
            ),
          ),
          section(
            'Height and body measurements',
            SegmentedButton<LengthUnit>(
              segments: const [
                ButtonSegment(value: LengthUnit.cm, label: Text('cm')),
                ButtonSegment(value: LengthUnit.ftIn, label: Text('ft / in')),
              ],
              selected: {s.lengthUnit},
              showSelectedIcon: false,
              onSelectionChanged: (v) => notifier.update((x) => x.copyWith(lengthUnit: v.first)),
            ),
          ),
          section(
            'Water',
            SegmentedButton<WaterUnit>(
              segments: const [
                ButtonSegment(value: WaterUnit.ml, label: Text('Millilitres (ml)')),
                ButtonSegment(value: WaterUnit.flOz, label: Text('Fluid ounces')),
              ],
              selected: {s.waterUnit},
              showSelectedIcon: false,
              onSelectionChanged: (v) => notifier.update((x) => x.copyWith(waterUnit: v.first)),
            ),
          ),
          Text('Your records are stored in metric units, so switching never changes them.', style: t.bodySmall),
          const SectionTitle('Defaults'),
          GroupCard(
            children: [
              ListTile(
                title: const Text('Default rest between sets'),
                subtitle: const Text('Used for exercises you add without their own rest time'),
                trailing: Text('${s.defaultRestSeconds} s', style: t.titleSmall),
                onTap: () async {
                  final v = await showNumberInputDialog(
                    context,
                    title: 'Default rest',
                    label: 'Seconds',
                    initial: s.defaultRestSeconds.toDouble(),
                    decimal: false,
                    min: 5,
                    max: 3600,
                  );
                  if (v != null) await notifier.update((x) => x.copyWith(defaultRestSeconds: v.round()));
                },
              ),
              ListTile(
                title: const Text('Glass size for water'),
                subtitle: const Text('Amount added by the quick "glass" button'),
                trailing: Text(formatWater(s.glassSizeMl, s.waterUnit), style: t.titleSmall),
                onTap: () async {
                  final v = await showNumberInputDialog(
                    context,
                    title: 'Glass size',
                    label: s.waterUnit.label,
                    initial: double.parse(formatNumber(waterForDisplay(s.glassSizeMl, s.waterUnit))),
                    max: s.waterUnit == WaterUnit.ml ? 2000 : 70,
                  );
                  if (v != null) await notifier.update((x) => x.copyWith(glassSizeMl: waterToMl(v, s.waterUnit)));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
