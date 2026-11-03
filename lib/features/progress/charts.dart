import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/format.dart';

/// A "nice" axis step (1, 2, 2.5 or 5 × 10ⁿ) close to [rough].
double niceStep(double rough) {
  if (rough <= 0 || rough.isNaN) return 1;
  final base = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
  final f = rough / base;
  final nice = f <= 1
      ? 1.0
      : f <= 2
      ? 2.0
      : f <= 2.5
      ? 2.5
      : f <= 5
      ? 5.0
      : 10.0;
  return nice * base;
}

bool isMultipleOf(double value, double step) {
  final q = value / step;
  return (q - q.round()).abs() < 1e-6;
}

/// Y-axis bounds on round numbers with a little room above and below.
class AxisRange {
  const AxisRange(this.min, this.max, this.step);
  final double min;
  final double max;
  final double step;

  factory AxisRange.around(double lo, double hi) {
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final step = niceStep((hi - lo) / 4);
    var min = (lo / step).floor() * step;
    var max = (hi / step).ceil() * step;
    if ((lo - min).abs() < step * 0.1) min -= step;
    if ((max - hi).abs() < step * 0.1) max += step;
    return AxisRange(min, max, step);
  }
}

/// A dated value. Only real records are plotted; missing days stay empty.
class DatedValue {
  const DatedValue(this.date, this.value);
  final String date;
  final double value;
}

/// Line chart over calendar time: points are placed by date, so gaps between
/// records show as gaps in time rather than evenly spaced points.
class DatedLineChart extends StatelessWidget {
  const DatedLineChart({
    super.key,
    required this.points,
    required this.unit,
    this.height = 190,
    this.decimals = 1,
    this.color,
  });
  final List<DatedValue> points;
  final String unit;
  final double height;
  final int decimals;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.accent;
    if (points.isEmpty) return SizedBox(height: height);
    final first = parseDateKey(points.first.date);
    double x(String d) => parseDateKey(d).difference(first).inDays.toDouble();
    final spots = [for (final pt in points) FlSpot(x(pt.date), pt.value)];
    final values = points.map((e) => e.value);
    final axis = AxisRange.around(values.reduce(math.min), values.reduce(math.max));
    final minY = axis.min, maxY = axis.max;
    final maxX = math.max(spots.last.x, 1.0);
    final xStep = math.max(1.0, (maxX / 3).ceilToDouble());
    final labelStyle = TextStyle(fontSize: 11, color: p.textMuted);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: axis.step,
            getDrawingHorizontalLine: (_) => FlLine(color: p.border, strokeWidth: 0.8),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: axis.step,
                getTitlesWidget: (v, meta) => !isMultipleOf(v, axis.step)
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(formatNumber(v, decimals: 2), style: labelStyle),
                      ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: xStep,
                getTitlesWidget: (v, meta) => !isMultipleOf(v, xStep)
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                        child: Text(formatShortDate(addDays(first, v.round())), style: labelStyle),
                      ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => p.elevated,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${formatNumber(s.y, decimals: decimals)} $unit\n${formatShortDate(addDays(first, s.x.round()))}',
                    TextStyle(color: p.text, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: c,
              barWidth: 2.5,
              isCurved: false,
              dotData: FlDotData(
                show: spots.length <= 40,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 3, color: c, strokeWidth: 0),
              ),
              belowBarData: BarAreaData(show: true, color: c.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bar per day, with an optional dashed target line. Days without data
/// get no bar.
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({
    super.key,
    required this.days,
    required this.values,
    this.target,
    this.unit = 'kcal',
    this.height = 180,
  });

  /// Date keys, oldest first.
  final List<String> days;
  final Map<String, double> values;
  final double? target;
  final String unit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final maxValue = [...values.values, target ?? 0].fold<double>(0, math.max);
    final step = niceStep((maxValue <= 0 ? 100 : maxValue * 1.1) / 4);
    final maxY = math.max(step, (maxValue * 1.1 / step).ceil() * step);
    final labelStyle = TextStyle(fontSize: 11, color: p.textMuted);
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: step,
            getDrawingHorizontalLine: (_) => FlLine(color: p.border, strokeWidth: 0.8),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (target != null && target! > 0)
                HorizontalLine(y: target!, color: p.textSecondary, strokeWidth: 1, dashArray: const [5, 4]),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: step,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    v >= 1000 ? '${formatNumber(v / 1000)}k' : formatNumber(v, decimals: 0),
                    style: labelStyle,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(weekdayShort(parseDateKey(days[i]).weekday), style: labelStyle),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => p.elevated,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${formatThousands(rod.toY)} $unit\n${formatShortDate(parseDateKey(days[group.x]))}',
                TextStyle(color: p.text, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  if (values[days[i]] != null)
                    BarChartRodData(
                      toY: values[days[i]]!,
                      width: 16,
                      color: target != null && values[days[i]]! > target! ? p.warning : p.accent,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Period filter for charts.
class PeriodChips extends StatelessWidget {
  const PeriodChips({super.key, required this.selected, required this.onChanged});

  /// Days, or null for all time.
  final int? selected;
  final ValueChanged<int?> onChanged;

  static const options = <(int?, String)>[(7, '7 days'), (30, '30 days'), (90, '90 days'), (null, 'All')];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      spacing: 8,
      children: [
        for (final (days, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: selected == days,
            showCheckmark: false,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, color: selected == days ? p.onAccent : p.text),
            onSelected: (_) => onChanged(days),
          ),
      ],
    );
  }
}
