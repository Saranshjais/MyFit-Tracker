import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/feedback.dart';
import '../settings/data_actions.dart';
import 'backup_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  static String describe(Map<String, int> counts) {
    final parts = [
      '${counts['workout_sessions'] ?? 0} workouts',
      '${counts['food_logs'] ?? 0} food entries',
      '${counts['body_weight_logs'] ?? 0} weigh-ins',
      '${counts['saved_meals'] ?? 0} saved meals',
      '${counts['body_measurements'] ?? 0} measurements',
    ];
    return parts.join(', ');
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final data = await service.export();
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
      final fileName = 'myfit-backup-${dateKey(ref.read(todayProvider))}.json';
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: 'Save backup',
      );
      if (!mounted) return;
      if (saved == null) {
        showSnack(context, 'Export cancelled.');
      } else {
        final counts = {for (final e in (data['tables'] as Map).entries) e.key as String: (e.value as List).length};
        showSnack(context, 'Backup saved: ${describe(counts)}.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not export: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(dialogTitle: 'Choose a MyFit Tracker backup');
      if (file == null || !mounted) return;
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(await file.readAsBytes()));
      } on FormatException {
        if (mounted) await _error('That file is not a valid backup (it is not readable JSON). Nothing was changed.');
        return;
      }
      final service = ref.read(backupServiceProvider);
      final check = BackupService.validate(decoded, await service.columns());
      if (!mounted) return;
      if (!check.isValid) {
        await _error('${check.errors.join('\n')}\n\nNothing was changed.');
        return;
      }
      final ok = await showConfirmDialog(
        context,
        title: 'Replace all data?',
        message:
            'Backup${check.exportedAt == null ? '' : ' from ${formatMediumDate(check.exportedAt!)}'} contains '
            '${describe(check.counts)}.\n\nRestoring replaces everything currently in the app. '
            'If anything goes wrong, your current data is kept.',
        confirm: 'Restore',
        destructive: true,
      );
      if (!ok) return;
      await service.import(decoded);
      await reloadAfterDataChange(ref);
      if (mounted) showSnack(context, 'Backup restored.');
    } on BackupException catch (e) {
      if (mounted) await _error(e.message);
    } catch (e) {
      if (mounted) await _error('Could not restore: $e\n\nYour existing data has not been changed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _error(String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restore failed'),
      content: SingleChildScrollView(child: Text(message)),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: pagePadding,
        children: [
          AppCard(
            color: p.backgroundAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.phone_android, color: p.accentText),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your data is stored only on this phone and is not backed up to any cloud by this app. '
                    'Uninstalling the app or resetting the phone deletes it. Export a backup regularly and keep the file somewhere safe, '
                    'for example Google Drive or email to yourself.',
                    style: t.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Export'),
          Text(
            'Saves profile, settings, plans, workout history, food diary, saved meals, custom foods, weight, measurements, water and reminders as one JSON file.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Export backup'),
          ),
          const SectionTitle('Restore'),
          Text(
            'The file is checked first. If it is invalid or does not fit together, nothing is changed.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Restore from backup'),
          ),
          if (_busy) const LoadingView(padding: EdgeInsets.all(20)),
        ],
      ),
    );
  }
}
