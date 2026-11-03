import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../settings/app_settings.dart';
import 'body_repository.dart';
import 'charts.dart';
import 'progress_stats.dart';

class MeasurementsScreen extends ConsumerStatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  ConsumerState<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends ConsumerState<MeasurementsScreen> {
  String? _type;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final unit = ref.watch(settingsProvider).lengthUnit;
    final all = ref.watch(measurementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Body measurements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showMeasurementSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: AsyncView(
        value: all,
        builder: (all) {
          if (all.isEmpty) {
            return EmptyState(
              icon: Icons.straighten,
              title: 'No measurements yet',
              message: 'Measure at the same spot each time, relaxed, with a flexible tape.',
              action: 'Add a measurement',
              onAction: () => showMeasurementSheet(context),
            );
          }
          final latest = latestMeasurements(all);
          final types = latest.keys.toList();
          final type = types.contains(_type) ? _type! : types.first;
          final series = all.where((m) => m.type == type).toList().reversed.toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ty in types)
                    ChoiceChip(
                      label: Text('$ty · ${formatLength(latest[ty]!.valueCm, unit)}'),
                      selected: ty == type,
                      showCheckmark: false,
                      labelStyle: TextStyle(fontWeight: FontWeight.w600, color: ty == type ? p.onAccent : p.text),
                      onSelected: (_) => setState(() => _type = ty),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (series.length >= 2)
                AppCard(
                  child: DatedLineChart(
                    points: [for (final m in series) DatedValue(m.date, lengthForDisplay(m.valueCm, unit))],
                    unit: lengthUnitLabel(unit),
                    color: p.carbs,
                  ),
                ),
              SectionTitle('$type history'),
              for (final m in series.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AppCard(
                    onTap: () => showMeasurementSheet(context, existing: m),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(formatMediumDate(parseDateKey(m.date)), style: t.bodyMedium)),
                        Text(formatLength(m.valueCm, unit), style: t.titleSmall),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> showMeasurementSheet(BuildContext context, {Measurement? existing}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _MeasurementSheet(existing: existing),
);

class _MeasurementSheet extends ConsumerStatefulWidget {
  const _MeasurementSheet({this.existing});
  final Measurement? existing;

  @override
  ConsumerState<_MeasurementSheet> createState() => _MeasurementSheetState();
}

class _MeasurementSheetState extends ConsumerState<_MeasurementSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _value;
  late final TextEditingController _custom;
  late String _type;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final unit = ref.read(settingsProvider).lengthUnit;
    _type = e == null ? measurementTypes.first : (measurementTypes.contains(e.type) ? e.type : 'Other');
    _custom = TextEditingController(text: e != null && !measurementTypes.contains(e.type) ? e.type : '');
    _value = TextEditingController(text: e == null ? '' : formatNumber(lengthForDisplay(e.valueCm, unit), decimals: 1));
    _date = e == null ? ref.read(todayProvider) : parseDateKey(e.date);
  }

  @override
  void dispose() {
    _value.dispose();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final unit = ref.read(settingsProvider).lengthUnit;
    final cm = lengthToCm(parseDecimal(_value.text)!, unit);
    final type = _type == 'Other' ? _custom.text.trim() : _type;
    final repo = ref.read(bodyRepositoryProvider);
    final ok = await runGuarded(context, () async {
      if (widget.existing == null) {
        await repo.addMeasurement(date: dateKey(_date), type: type, valueCm: cm);
      } else {
        await repo.updateMeasurement(
          Measurement(id: widget.existing!.id, date: dateKey(_date), type: type, valueCm: cm),
        );
      }
      ref.read(bodyRevisionProvider.notifier).bump();
    });
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete measurement?',
      message: 'This entry will be removed.',
      confirm: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(bodyRepositoryProvider).deleteMeasurement(widget.existing!.id);
    ref.read(bodyRevisionProvider.notifier).bump();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final unit = ref.watch(settingsProvider).lengthUnit;
    final today = ref.watch(todayProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existing == null ? 'Add measurement' : 'Edit measurement', style: t.titleLarge),
              const SizedBox(height: 16),
              LabeledDropdown<String>(
                label: 'What',
                value: _type,
                items: [...measurementTypes, 'Other'],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              if (_type == 'Other') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _custom,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                ),
              ],
              const SizedBox(height: 12),
              DecimalField(
                controller: _value,
                label: 'Measurement',
                suffix: lengthUnitLabel(unit),
                validator: (v) =>
                    validateRequiredNumber(v, min: 1, max: unit == LengthUnit.cm ? 300 : 120, label: 'Value'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(relativeDayLabel(_date, today)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2015),
                    lastDate: today,
                  );
                  if (picked != null) setState(() => _date = dateOnly(picked));
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.existing != null) ...[
                    OutlinedButton(
                      onPressed: _delete,
                      style: OutlinedButton.styleFrom(foregroundColor: context.palette.error),
                      child: const Text('Delete'),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton(onPressed: _save, child: const Text('Save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
