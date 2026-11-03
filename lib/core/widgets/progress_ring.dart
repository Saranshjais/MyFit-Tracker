import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Thin circular progress indicator with optional centred content.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.fraction,
    this.size = 120,
    this.stroke = 10,
    this.color,
    this.trackColor,
    this.child,
    this.over = false,
  });

  /// 0–1.
  final double fraction;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;
  final Widget? child;

  /// Draws the ring in the warning colour when a target is exceeded.
  final bool over;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: fraction.clamp(0, 1).toDouble(),
          stroke: stroke,
          color: over ? p.warning : (color ?? p.accent),
          track: trackColor ?? p.elevated,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.stroke, required this.color, required this.track});
  final double fraction;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base);
    if (fraction <= 0) return;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * fraction, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track || old.stroke != stroke;
}

/// Horizontal macro bar with label and "consumed / target".
class MacroBar extends StatelessWidget {
  const MacroBar({super.key, required this.label, required this.consumed, this.target, required this.color});
  final String label;
  final double consumed;
  final double? target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final hasTarget = target != null && target! > 0;
    final fraction = hasTarget ? (consumed / target!).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Text(
              hasTarget ? '${consumed.round()} / ${target!.round()} g' : '${consumed.round()} g',
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            color: hasTarget && consumed > target! ? p.warning : color,
            backgroundColor: p.elevated,
          ),
        ),
      ],
    );
  }
}
