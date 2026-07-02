// lib/views/widgets/radar_painter.dart

import 'dart:math';
import 'package:flutter/material.dart';

class RadarPainter extends CustomPainter {
  final double angle;
  final double pulseValue;

  RadarPainter({required this.angle, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2;

    // Rings paint
    final paintRing = Paint()
      ..color = Colors.cyan.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric rings
    canvas.drawCircle(center, maxRadius * 0.25, paintRing);
    canvas.drawCircle(center, maxRadius * 0.50, paintRing);
    canvas.drawCircle(center, maxRadius * 0.75, paintRing);
    canvas.drawCircle(center, maxRadius, paintRing);

    // Draw grid crosshairs
    final paintLine = Paint()
      ..color = Colors.cyan.withAlpha(20)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      paintLine,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      paintLine,
    );

    // Draw pulsing ring (expanding outwards)
    final paintPulse = Paint()
      ..color = Colors.cyan.withOpacity(0.3 * (1.0 - pulseValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, maxRadius * pulseValue, paintPulse);

    // Draw scanning sweep (rotating line with a gradient fade)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: 2 * pi,
        colors: [
          Colors.cyan.withOpacity(0.0),
          Colors.cyan.withOpacity(0.35),
        ],
        stops: const [0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final sweepRect = Rect.fromCircle(center: Offset.zero, radius: maxRadius);
    canvas.drawArc(sweepRect, 0, 2 * pi, true, sweepPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.pulseValue != pulseValue;
  }
}
