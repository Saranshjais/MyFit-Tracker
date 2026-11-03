import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/widgets/cards.dart';
import 'body_map.dart';
import 'exercise.dart';

/// Icon per muscle group, used when an exercise has no specific muscles
/// (older custom exercises).
IconData muscleIcon(String muscle) => switch (muscle) {
  'Chest' => Icons.fitness_center,
  'Back' => Icons.rowing,
  'Shoulders' => Icons.sports_gymnastics,
  'Arms' => Icons.sports_mma,
  'Legs' => Icons.directions_walk,
  'Core' => Icons.self_improvement,
  'Cardio' => Icons.directions_run,
  'Full Body' => Icons.accessibility_new,
  _ => Icons.fitness_center,
};

/// Square thumbnail: a small body figure with the worked muscles highlighted.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({super.key, required this.exercise, this.size = 48});
  final Exercise exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (exercise.targetMuscles.isEmpty) return IconTile(icon: muscleIcon(exercise.muscle), size: size);
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.backgroundAlt, borderRadius: BorderRadius.circular(size * 0.26)),
      child: BodyMap(
        primary: exercise.targetMuscles,
        secondary: exercise.assistMuscles,
        view: preferredView(exercise.targetMuscles),
        height: size - 6,
        focus: true,
        focusAspect: 1,
      ),
    );
  }
}

/// Header for the session and detail screens: front and back figures with
/// the main and supporting muscles highlighted.
class ExerciseHero extends StatelessWidget {
  const ExerciseHero({super.key, required this.exercise, this.height = 150, this.focus = false});
  final Exercise exercise;
  final double height;

  /// Zoom in on the worked muscles (for compact headers).
  final bool focus;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasMuscles = exercise.targetMuscles.isNotEmpty;
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(color: p.backgroundAlt, borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          Center(
            child: hasMuscles
                ? BodyMap(
                    primary: exercise.targetMuscles,
                    secondary: exercise.assistMuscles,
                    height: height - 40,
                    labels: true,
                    focus: focus,
                  )
                : Icon(muscleIcon(exercise.muscle), size: height * 0.5, color: p.accentText),
          ),
          Positioned(
            left: 2,
            bottom: 0,
            child: Text(
              exercise.equipment,
              style: TextStyle(color: p.accentText, fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Builds: Chest (pecs) · Also: Front shoulders, Triceps" in two lines.
class MuscleSummary extends StatelessWidget {
  const MuscleSummary({super.key, required this.exercise, this.maxLines});
  final Exercise exercise;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    if (exercise.targetMuscles.isEmpty) return Text(exercise.muscle, style: t.bodySmall);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Builds: ',
            style: TextStyle(color: p.textSecondary),
          ),
          TextSpan(
            text: exercise.targetMuscles.map((m) => m.label).join(', '),
            style: TextStyle(color: p.accentText, fontWeight: FontWeight.w600),
          ),
          if (exercise.assistMuscles.isNotEmpty)
            TextSpan(
              text: '\nAlso: ${exercise.assistMuscles.map((m) => m.label).join(', ')}',
              style: TextStyle(color: p.textSecondary),
            ),
        ],
      ),
      style: t.bodySmall,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
