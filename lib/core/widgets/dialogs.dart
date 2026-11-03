import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_palette.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Confirm',
  String cancel = 'Cancel',
  bool destructive = false,
}) async {
  final p = context.palette;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: p.textSecondary),
          child: Text(cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive ? FilledButton.styleFrom(backgroundColor: p.error, foregroundColor: Colors.white) : null,
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Single text field dialog (rename, new category). Returns null on cancel.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String label = 'Name',
  String confirm = 'Save',
  int maxLength = 60,
}) {
  final controller = TextEditingController(text: initial);
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          maxLength: maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label, counterText: ''),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
          onFieldSubmitted: (_) {
            if (formKey.currentState!.validate()) Navigator.pop(context, controller.text.trim());
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(context, controller.text.trim());
          },
          child: Text(confirm),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Numeric dialog with validation. Returns null on cancel.
Future<double?> showNumberInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  double? initial,
  String? suffix,
  double min = 0,
  double max = 100000,
  bool allowZero = false,
  bool decimal = true,
  String? helper,
}) {
  final controller = TextEditingController(text: initial == null ? '' : _trim(initial));
  final formKey = GlobalKey<FormState>();
  double? parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));
  return showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
          decoration: InputDecoration(labelText: label, suffixText: suffix, helperText: helper, helperMaxLines: 3),
          validator: (v) {
            final value = parse(v ?? '');
            if (value == null) return 'Enter a number';
            if (value < min || (!allowZero && value == 0)) return 'Must be more than ${_trim(min)}';
            if (value > max) return 'Must be at most ${_trim(max)}';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(context, parse(controller.text));
          },
          child: const Text('Save'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Bottom sheet listing choices. Returns the chosen value or null.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<({T value, String label, String? subtitle, IconData? icon})> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(
                      leading: o.icon == null ? null : Icon(o.icon),
                      title: Text(o.label),
                      subtitle: o.subtitle == null ? null : Text(o.subtitle!),
                      trailing: o.value == selected ? Icon(Icons.check, color: context.palette.accentText) : null,
                      onTap: () => Navigator.pop(context, o.value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
