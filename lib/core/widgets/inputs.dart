import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';
import '../utils/dates.dart';

/// Two or more green pill tabs ("Week Plan | Exercise Library").
class PillTabs extends StatelessWidget {
  const PillTabs({super.key, required this.labels, required this.selected, required this.onChanged});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: i == selected ? p.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: i == selected ? p.onAccent : p.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "‹  Mon, 12 Aug 2024  ›" date selector. Tapping the label opens a picker.
class DateNavigator extends StatelessWidget {
  const DateNavigator({
    super.key,
    required this.date,
    required this.today,
    required this.onChanged,
    this.allowFuture = false,
  });
  final DateTime date;
  final DateTime today;
  final ValueChanged<DateTime> onChanged;
  final bool allowFuture;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final canGoForward = allowFuture || dateOnly(date).isBefore(dateOnly(today));
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous day',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(addDays(date, -1)),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2015),
                  lastDate: allowFuture ? addDays(today, 365) : today,
                );
                if (picked != null) onChanged(dateOnly(picked));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  isSameDay(date, today) ? 'Today, ${formatShortDate(date)}' : formatMediumDate(date),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoForward ? () => onChanged(addDays(date, 1)) : null,
          ),
        ],
      ),
    );
  }
}

/// Text field for decimal numbers (weights, quantities). Accepts "," or ".".
class DecimalField extends StatelessWidget {
  const DecimalField({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.validator,
    this.onChanged,
    this.decimal = true,
    this.helper,
    this.textInputAction,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool decimal;
  final String? helper;
  final TextInputAction? textInputAction;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    autofocus: autofocus,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
    textInputAction: textInputAction ?? TextInputAction.next,
    decoration: InputDecoration(labelText: label, suffixText: suffix, helperText: helper, helperMaxLines: 3),
    validator: validator,
    onChanged: onChanged,
  );
}

/// Dropdown bound to a list of values with labels.
class LabeledDropdown<T> extends StatelessWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
    this.hint,
  });

  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T item)? itemLabel;
  final String? hint;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    // initialValue is only read once; the key resets the field when the
    // value is changed from outside.
    key: ValueKey(value),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    hint: hint == null ? null : Text(hint!),
    dropdownColor: context.palette.elevated,
    items: [
      for (final item in items)
        DropdownMenuItem<T>(
          value: item,
          child: Text(itemLabel?.call(item) ?? '$item', overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  );
}
