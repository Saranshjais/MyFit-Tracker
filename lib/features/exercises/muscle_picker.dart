import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'body_map.dart';
import 'muscles.dart';

enum MuscleRole { none, main, assist }

/// Pick the muscles an exercise works, grouped by body part. Each tap cycles
/// a muscle: not worked → main → also works → not worked.
class MusclePicker extends StatelessWidget {
  const MusclePicker({super.key, required this.targets, required this.assists, required this.onChanged, this.error});

  final Set<Muscle> targets;
  final Set<Muscle> assists;
  final void Function(Set<Muscle> targets, Set<Muscle> assists) onChanged;
  final String? error;

  MuscleRole roleOf(Muscle m) => targets.contains(m)
      ? MuscleRole.main
      : assists.contains(m)
      ? MuscleRole.assist
      : MuscleRole.none;

  void _cycle(Muscle m) {
    final t = {...targets}, a = {...assists};
    switch (roleOf(m)) {
      case MuscleRole.none:
        t.add(m);
      case MuscleRole.main:
        t.remove(m);
        a.add(m);
      case MuscleRole.assist:
        a.remove(m);
    }
    onChanged(t, a);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: BodyMap(primary: targets, secondary: assists, height: 170, labels: true),
        ),
        const SizedBox(height: 8),
        const BodyMapLegend(),
        const SizedBox(height: 12),
        Text(
          'Tap a muscle once for a main muscle, again for a supporting one, and once more to clear it.',
          style: tt.bodySmall,
        ),
        if (error != null) ...[const SizedBox(height: 6), Text(error!, style: tt.bodySmall?.copyWith(color: p.error))],
        for (final part in BodyPart.values) ...[
          const SizedBox(height: 14),
          Text(part.label, style: tt.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in Muscle.values.where((m) => m.part == part))
                _MuscleChip(muscle: m, role: roleOf(m), onTap: () => _cycle(m)),
            ],
          ),
        ],
      ],
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.muscle, required this.role, required this.onTap});
  final Muscle muscle;
  final MuscleRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg, border) = switch (role) {
      MuscleRole.main => (p.accent, p.onAccent, p.accent),
      MuscleRole.assist => (p.accentSoft, p.accentText, p.accent),
      MuscleRole.none => (p.surface, p.text, p.border),
    };
    return Semantics(
      button: true,
      label:
          '${muscle.label}: ${switch (role) {
            MuscleRole.main => 'main muscle',
            MuscleRole.assist => 'supporting muscle',
            MuscleRole.none => 'not worked',
          }}',
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (role != MuscleRole.none) ...[
                Icon(role == MuscleRole.main ? Icons.star : Icons.add, size: 15, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                muscle.label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
