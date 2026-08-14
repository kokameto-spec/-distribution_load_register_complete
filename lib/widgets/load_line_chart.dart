import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LoadChartPoint {
  const LoadChartPoint({
    required this.time,
    required this.value,
  });

  final DateTime time;
  final double value;
}

class LoadLineChart extends StatelessWidget {
  const LoadLineChart({
    super.key,
    required this.title,
    required this.points,
    this.height = 220,
  });

  final String title;
  final List<LoadChartPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('$title: لا توجد بيانات كافية للرسم.'),
        ),
      );
    }

    final sorted = List<LoadChartPoint>.from(points)
      ..sort((a, b) => a.time.compareTo(b.time));

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: height,
              child: CustomPaint(
                painter: _LoadLineChartPainter(
                  points: sorted,
                  lineColor: Theme.of(context).colorScheme.onSurface,
                  gridColor: Theme.of(context).colorScheme.outlineVariant,
                  labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadLineChartPainter extends CustomPainter {
  _LoadLineChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<LoadChartPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 54.0;
    const right = 12.0;
    const top = 12.0;
    const bottom = 34.0;

    final chartWidth = math.max(1.0, size.width - left - right);
    final chartHeight = math.max(1.0, size.height - top - bottom);

    final values = points.map((item) => item.value).toList(growable: false);
    var minValue = values.reduce(math.min);
    var maxValue = values.reduce(math.max);

    if ((maxValue - minValue).abs() < 0.001) {
      minValue = math.max(0, minValue - 1);
      maxValue += 1;
    } else {
      final padding = (maxValue - minValue) * 0.08;
      minValue = math.max(0, minValue - padding);
      maxValue += padding;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(left + chartWidth, y),
        gridPaint,
      );

      final value = maxValue - (maxValue - minValue) * i / 4;
      _drawText(
        canvas,
        '${value.toStringAsFixed(0)} A',
        Offset(0, y - 8),
        maxWidth: left - 6,
        align: TextAlign.right,
      );
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * i / (points.length - 1);
      final ratio = (points[i].value - minValue) / (maxValue - minValue);
      final y = top + chartHeight * (1 - ratio);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      if (points.length <= 40 || i % math.max(1, points.length ~/ 30) == 0) {
        canvas.drawCircle(Offset(x, y), 2.3, pointPaint);
      }
    }
    canvas.drawPath(path, linePaint);

    final labelIndexes = <int>{0, points.length ~/ 2, points.length - 1}.toList()..sort();
    for (final index in labelIndexes) {
      final x = points.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * index / (points.length - 1);
      final text = DateFormat('dd/MM\nHH:mm').format(points[index].time);
      _drawText(
        canvas,
        text,
        Offset(x - 36, top + chartHeight + 5),
        maxWidth: 72,
        align: TextAlign.center,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double maxWidth,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: align,
      maxLines: 2,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LoadLineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}
