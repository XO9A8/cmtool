import 'package:flutter/material.dart';
import 'dart:math';

import '../theme/app_theme.dart';

class MpsRadarChart extends StatelessWidget {
  final double possession;
  final double passAccuracy;
  final double shotEfficiency;
  final double interceptions;
  final double formRating;

  const MpsRadarChart({
    super.key,
    required this.possession,
    required this.passAccuracy,
    required this.shotEfficiency,
    required this.interceptions,
    required this.formRating,
  });

  @override
  Widget build(BuildContext context) {
    // Normalize values to 0.0 - 1.0 range based on hypothetical maximums
    final normalizedPossession = (possession / 100.0).clamp(0.0, 1.0);
    final normalizedPasses = (passAccuracy / 100.0).clamp(0.0, 1.0);
    final normalizedShots = (shotEfficiency / 100.0).clamp(0.0, 1.0);
    // Assuming max 20 interceptions is top tier
    final normalizedInterceptions = (interceptions / 20.0).clamp(0.0, 1.0);
    final normalizedForm = (formRating / 100.0).clamp(0.0, 1.0);

    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: RadarChartPainter(
          values: [
            normalizedPossession,
            normalizedPasses,
            normalizedShots,
            normalizedInterceptions,
            normalizedForm
          ],
          labels: ['Possession', 'Passing', 'Shooting', 'Defending', 'Form'],
          color: AppColors.cyan,
        ),
      ),
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;

  RadarChartPainter({
    required this.values,
    required this.labels,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(center.dx, center.dy) * 0.8;
    final angle = 2 * pi / values.length;

    // Draw background web
    final gridPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i <= 4; i++) {
      final r = radius * (i / 4);
      final path = Path();
      for (var j = 0; j < values.length; j++) {
        final x = center.dx + r * cos(j * angle - pi / 2);
        final y = center.dy + r * sin(j * angle - pi / 2);
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw axes
    for (var i = 0; i < values.length; i++) {
      final x = center.dx + radius * cos(i * angle - pi / 2);
      final y = center.dy + radius * sin(i * angle - pi / 2);
      canvas.drawLine(center, Offset(x, y), gridPaint);
      
      // Draw labels
      final labelSpan = TextSpan(
        style: const TextStyle(color: Colors.white70, fontSize: 10),
        text: labels[i],
      );
      final textPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // Adjust label position slightly outwards
      const labelOffset = 15.0;
      final lx = center.dx + (radius + labelOffset) * cos(i * angle - pi / 2) - textPainter.width / 2;
      final ly = center.dy + (radius + labelOffset) * sin(i * angle - pi / 2) - textPainter.height / 2;
      textPainter.paint(canvas, Offset(lx, ly));
    }

    // Draw data polygon
    final dataPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    
    final dataOutlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final dataPath = Path();
    for (var i = 0; i < values.length; i++) {
      final valRadius = radius * values[i];
      final x = center.dx + valRadius * cos(i * angle - pi / 2);
      final y = center.dy + valRadius * sin(i * angle - pi / 2);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();
    
    canvas.drawPath(dataPath, dataPaint);
    canvas.drawPath(dataPath, dataOutlinePaint);
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
