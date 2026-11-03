import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';
import '../../core/utils/units.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../settings/app_settings.dart';
import 'body_repository.dart';

/// Add a weigh-in, or edit/delete [existing].
Future<void> showWeightEntrySheet(BuildContext context, {WeightLog? existing}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _WeightEntrySheet(existing: existing),
);

class _WeightEntrySheet extends ConsumerStatefulWidget {
  const _WeightEntrySheet({this.existing});
  final WeightLog? existing;

  @override
  ConsumerState<_WeightEntrySheet> createState() => _WeightEntrySheetState();
}

class _WeightEntrySheetState extends ConsumerState<_WeightEntrySheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _weight;
  late final TextEditingController _notes;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final unit = ref.read(settingsProvider).weightUnit;
    final e = widget.existing;
    _weight = TextEditingController(
      text: e == null ? '' : formatNumber(weightForDisplay(e.weightKg, unit), decimals: 2),
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _date = e == null ? ref.read(todayProvider) : parseDateKey(e.date);
  }

  @override
  void dispose() {
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final unit = ref.read(settingsProvider).weightUnit;
    final kg = weightToKg(parseDecimal(_weight.text)!, unit);
    final repo = ref.read(bodyRepositoryProvider);
    try {
      if (widget.existing == null) {
        await repo.recordWeight(dateKey(_date), kg, notes: _notes.text);
      } else {
        await repo.updateWeight(widget.existing!.id, date: dateKey(_date), kg: kg, notes: _notes.text);
      }
      ref.read(bodyRevisionProvider.notifier).bump();
      if (mounted) Navigator.pop(context);
    } on DuplicateDateException catch (e) {
      if (mounted) showSnack(context, e.toString());
    } on ArgumentError catch (e) {
      if (mounted) showSnack(context, '${e.message}');
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this entry?',
      message: 'The weigh-in for ${formatMediumDate(_date)} will be removed.',
      confirm: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(bodyRepositoryProvider).deleteWeight(widget.existing!.id);
    ref.read(bodyRevisionProvider.notifier).bump();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(settingsProvider).weightUnit;
    final today = ref.watch(todayProvider);
    final t = Theme.of(context).textTheme;
    final minKg = 20.0, maxKg = 400.0;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existing == null ? 'Record weight' : 'Edit weigh-in', style: t.titleLarge),
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
              DecimalField(
                controller: _weight,
                label: 'Weight',
                suffix: unit.label,
                autofocus: widget.existing == null,
                validator: (v) => validateRequiredNumber(
                  v,
                  min: weightForDisplay(minKg, unit).floorToDouble(),
                  max: weightForDisplay(maxKg, unit).ceilToDouble(),
                  label: 'Weight',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Note (optional)', counterText: ''),
              ),
              const SizedBox(height: 6),
              Text('Weighing at a similar time each day makes trends easier to read.', style: t.bodySmall),
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
