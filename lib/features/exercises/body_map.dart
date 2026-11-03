import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'muscles.dart';

enum BodyView { front, back }

/// The side of the body that shows most of [muscles] (front on a tie).
BodyView preferredView(Iterable<Muscle> muscles) {
  var front = 0, back = 0;
  for (final m in muscles) {
    if (m.side == MuscleSide.front) front++;
    if (m.side == MuscleSide.back) back++;
  }
  return back > front ? BodyView.back : BodyView.front;
}

/// Simplified anatomy figure with the worked muscles highlighted: main
/// muscles in the accent colour, supporting muscles in a lighter tint.
/// With [view] null both the front and back are shown side by side.
/// With [focus] the figure is zoomed in on the highlighted muscles, which
/// keeps small thumbnails readable.
class BodyMap extends StatelessWidget {
  const BodyMap({
    super.key,
    required this.primary,
    this.secondary = const [],
    this.view,
    this.height = 160,
    this.labels = false,
    this.focus = false,
    this.focusAspect = 0.8,
  });

  final Iterable<Muscle> primary;
  final Iterable<Muscle> secondary;
  final BodyView? view;
  final double height;

  /// Shows "Front" and "Back" under the figures.
  final bool labels;

  /// Zooms in on the highlighted muscles instead of showing the whole body.
  final bool focus;

  /// Width ÷ height of each figure when [focus] is on.
  final double focusAspect;

  static const _aspect = _canvasWidth / _canvasHeight;

  /// Region of the canvas around the shapes of [muscles] in [views], padded
  /// and widened to [aspect]. Null when none of the muscles appear.
  static Rect? _focusRect(Set<Muscle> muscles, Iterable<List<_Shape>> views, double aspect) {
    Rect? r;
    for (final shapes in views) {
      for (final s in shapes) {
        if (s.muscle == null || !muscles.contains(s.muscle)) continue;
        final b = s.path.getBounds();
        r = r == null ? b : r.expandToInclude(b);
      }
    }
    if (r == null) return null;
    r = r.inflate(9);
    var w = math.max(r.width, 44.0), h = math.max(r.height, 50.0);
    if (w / h < aspect) {
      w = h * aspect;
    } else {
      h = w / aspect;
    }
    final double left = (r.center.dx - w / 2).clamp(0.0, math.max(0.0, _canvasWidth - w));
    final double top = (r.center.dy - h / 2).clamp(0.0, math.max(0.0, _canvasHeight - h));
    return Rect.fromLTWH(left, top, w, h);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final main = primary.toSet();
    final extra = secondary.toSet().difference(main);
    final idle = Color.lerp(p.elevated, p.textMuted, 0.35)!;
    List<_Shape> shapesFor(BodyView v) => v == BodyView.front ? _frontShapes : _backShapes;
    // One zoom region for every figure shown, so front and back line up.
    final focusRect = !focus
        ? null
        : _focusRect(
            view == null ? {...main, ...extra} : main,
            view == null ? [_frontShapes, _backShapes] : [shapesFor(view!)],
            focusAspect,
          );
    Widget figure(BodyView v) => CustomPaint(
      size: Size(height * (focusRect == null ? _aspect : focusAspect), height),
      painter: _BodyPainter(
        shapes: shapesFor(v),
        focus: focusRect,
        primary: main,
        secondary: extra,
        base: p.elevated,
        idle: idle,
        primaryColor: p.accent,
        secondaryColor: Color.alphaBlend(p.accent.withValues(alpha: 0.42), idle),
        outline: p.backgroundAlt,
      ),
    );

    final names = [...main.map((m) => m.label), ...extra.map((m) => '${m.label} (supporting)')];
    final Widget content;
    if (view != null) {
      content = figure(view!);
    } else {
      final style = TextStyle(fontSize: 11, color: p.textMuted, fontWeight: FontWeight.w600);
      Widget side(BodyView v, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          figure(v),
          if (labels) ...[const SizedBox(height: 4), Text(label, style: style)],
        ],
      );
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          side(BodyView.front, 'Front'),
          SizedBox(width: height * 0.12),
          side(BodyView.back, 'Back'),
        ],
      );
    }
    return Semantics(
      label: names.isEmpty ? 'Body diagram' : 'Muscles worked: ${names.join(', ')}',
      child: ExcludeSemantics(child: content),
    );
  }
}

/// Small legend for the two highlight colours.
class BodyMapLegend extends StatelessWidget {
  const BodyMapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final idle = Color.lerp(p.elevated, p.textMuted, 0.35)!;
    final style = Theme.of(context).textTheme.bodySmall;
    Widget item(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        item(p.accent, 'Main muscles'),
        item(Color.alphaBlend(p.accent.withValues(alpha: 0.42), idle), 'Also works'),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Drawing. Shapes are defined on a 100 × 220 canvas facing the viewer; most
// are drawn on the right half and mirrored.

const double _canvasWidth = 100;
const double _canvasHeight = 220;

class _Shape {
  const _Shape(this.path, [this.muscle]);
  final Path path;

  /// Null for parts that are not a trackable muscle (head, hands, knees…).
  final Muscle? muscle;
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.shapes,
    this.focus,
    required this.primary,
    required this.secondary,
    required this.base,
    required this.idle,
    required this.primaryColor,
    required this.secondaryColor,
    required this.outline,
  });

  final List<_Shape> shapes;

  /// Canvas region to show; the whole body when null.
  final Rect? focus;
  final Set<Muscle> primary;
  final Set<Muscle> secondary;
  final Color base;
  final Color idle;
  final Color primaryColor;
  final Color secondaryColor;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final region = focus ?? const Rect.fromLTWH(0, 0, _canvasWidth, _canvasHeight);
    final scale = math.min(size.width / region.width, size.height / region.height);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - region.width * scale) / 2, (size.height - region.height * scale) / 2);
    canvas.scale(scale);
    canvas.translate(-region.left, -region.top);
    final fill = Paint()..style = PaintingStyle.fill;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      // About 1.2 px on screen at any zoom.
      ..strokeWidth = 1.2 / scale
      ..strokeJoin = StrokeJoin.round
      ..color = outline;
    for (final s in shapes) {
      final m = s.muscle;
      fill.color = m == null
          ? base
          : primary.contains(m)
          ? primaryColor
          : secondary.contains(m)
          ? secondaryColor
          : idle;
      canvas.drawPath(s.path, fill);
      canvas.drawPath(s.path, edge);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.shapes != shapes ||
      old.focus != focus ||
      !_sameSet(old.primary, primary) ||
      !_sameSet(old.secondary, secondary) ||
      old.primaryColor != primaryColor ||
      old.idle != idle ||
      old.base != base;

  static bool _sameSet(Set<Muscle> a, Set<Muscle> b) => a.length == b.length && a.containsAll(b);
}

Float64List _affine(double a, double b, double c, double d, double tx, double ty) =>
    Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1]);

Path _oval(double cx, double cy, double rx, double ry, [double angle = 0]) {
  final p = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2));
  final c = math.cos(angle), s = math.sin(angle);
  return p.transform(_affine(c, s, -s, c, cx, cy));
}

Path _poly(List<double> xy) {
  final p = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    p.lineTo(xy[i], xy[i + 1]);
  }
  return p..close();
}

Path _rect(double l, double t, double r, double b) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, const Radius.circular(1.6)));

Path _mirror(Path p) => p.transform(_affine(-1, 0, 0, 1, _canvasWidth, 0));

/// The shape and its mirror image on the other side of the body.
List<_Shape> _pair(Path right, [Muscle? muscle]) => [_Shape(right, muscle), _Shape(_mirror(right), muscle)];

// Parts shared by both views.
final _head = _Shape(_oval(50, 14, 9, 11));
final _neck = _Shape(_poly([45.5, 23, 54.5, 23, 56, 31, 44, 31]));
final _hands = _pair(_oval(78.5, 100, 3.2, 5));
final _knees = _pair(_oval(58.5, 164, 4.6, 3.6));
final _feet = _pair(_oval(58.5, 211, 4.8, 3));
final _forearms = _pair(_oval(75.8, 82, 3.8, 13, -0.14), Muscle.forearms);
final _sideDelts = _pair(_oval(71.5, 43, 3.2, 7, -0.2), Muscle.sideDelts);

final List<_Shape> _frontShapes = [
  _head,
  _neck,
  ..._pair(_poly([50, 99, 58, 99, 62, 104, 60, 113, 52, 117, 50, 117])), // hips
  ..._hands,
  ..._knees,
  ..._pair(_poly([54.5, 168, 62.5, 168, 63, 186, 60.5, 206, 56, 206, 54, 186])), // shins
  ..._feet,
  ..._pair(_poly([54, 28, 63, 33.5, 56, 34.5]), Muscle.traps),
  ..._pair(_oval(66, 41, 5.6, 7.6, 0.35), Muscle.frontDelts),
  ..._sideDelts,
  ..._pair(_poly([50.8, 35, 60, 33.8, 64.5, 37.5, 63.8, 43, 50.8, 44.6]), Muscle.chestUpper),
  ..._pair(_poly([50.8, 44.6, 63.8, 43, 64.6, 48.5, 62, 54.5, 56, 57.5, 50.8, 57.5]), Muscle.chest),
  ..._pair(_oval(72.8, 58.5, 4.3, 10.2, -0.12), Muscle.biceps),
  ..._forearms,
  for (var row = 0; row < 4; row++) ..._pair(_rect(50.6, 59.5 + row * 10, 54.6, 68.3 + row * 10), Muscle.abs),
  ..._pair(_poly([55.5, 59, 62, 56.5, 63.6, 70, 61.6, 86, 57.5, 98.5, 55.5, 98.5]), Muscle.obliques),
  ..._pair(_poly([51.6, 116, 61, 106.5, 65.8, 118, 65.2, 140, 61.2, 160, 55.2, 160, 52.6, 140]), Muscle.quads),
  ..._pair(_poly([50.4, 117, 51.8, 116.5, 53.6, 138, 51.2, 145, 50.4, 141]), Muscle.adductors),
];

final List<_Shape> _backShapes = [
  _head,
  _neck,
  ..._pair(_poly([50.4, 98, 57, 100, 62.5, 106, 61, 112, 52, 113, 50.4, 113])), // pelvis
  ..._hands,
  ..._knees,
  ..._pair(_poly([55, 168, 62.5, 167, 63, 186, 60.5, 206, 56, 206, 54, 186])), // lower legs
  ..._feet,
  ..._pair(_poly([54.6, 49, 61.5, 43.5, 64, 50, 61.6, 57.5, 55.2, 60]), Muscle.upperBack),
  ..._pair(_poly([55, 61, 62.6, 56, 65.2, 63, 63.2, 79, 58.2, 92.5, 54.6, 92.5, 54.2, 75]), Muscle.lats),
  ..._pair(_poly([50.6, 62, 53.8, 62, 54.4, 94, 52.4, 101, 50.6, 101]), Muscle.lowerBack),
  _Shape(
    _poly([50, 24.5, 57, 29.5, 66, 34.5, 58.5, 39.5, 54.5, 50, 50, 59, 45.5, 50, 41.5, 39.5, 34, 34.5, 43, 29.5]),
    Muscle.traps,
  ),
  ..._pair(_oval(66, 41, 5.6, 7.6, 0.35), Muscle.rearDelts),
  ..._sideDelts,
  ..._pair(_oval(72.8, 58.5, 4.3, 10.2, -0.12), Muscle.triceps),
  ..._forearms,
  ..._pair(_oval(57.6, 112, 7.8, 9.6), Muscle.glutes),
  ..._pair(_poly([51.6, 124, 64, 120, 65.2, 140, 61.4, 160, 55.2, 160, 52.2, 140]), Muscle.hamstrings),
  ..._pair(_poly([50.4, 122, 51.6, 124, 52.2, 140, 50.4, 146]), Muscle.adductors),
  ..._pair(_poly([54.6, 168.5, 62.2, 167, 63.8, 180, 61.2, 195.5, 56.6, 198, 54.2, 182]), Muscle.calves),
];
