import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

import '../theme/app_theme.dart';

class MpsRadarChart extends StatelessWidget {
  final double possession;
  final double passAccuracy;
  final double shotEfficiency;
  final double interceptions;
  final double formRating;
  final double? attackingScore;
  final double? resilienceScore;
  final Color? primaryColor;
  final List<String>? customLabels;
  final List<double>? customValues;

  const MpsRadarChart({
    super.key,
    required this.possession,
    required this.passAccuracy,
    required this.shotEfficiency,
    required this.interceptions,
    required this.formRating,
    this.attackingScore,
    this.resilienceScore,
    this.primaryColor,
    this.customLabels,
    this.customValues,
  });

  @override
  Widget build(BuildContext context) {
    if (customValues != null && customLabels != null) {
      return AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: RadarChartPainter(
            values: customValues!,
            labels: customLabels!,
            color: primaryColor ?? AppColors.cyan,
          ),
        ),
      );
    }

    // 6-Pillar Performance Calculations (Normalized 0.05 - 1.0 range)
    final normalizedPossession = (possession / 100.0).clamp(0.05, 1.0);
    final normalizedPasses = (passAccuracy / 100.0).clamp(0.05, 1.0);
    final normalizedShots = attackingScore != null
        ? (attackingScore! / 100.0).clamp(0.05, 1.0)
        : (shotEfficiency / 100.0).clamp(0.05, 1.0);
    final normalizedDefending = (interceptions / 15.0).clamp(0.05, 1.0);
    final normalizedResilience = resilienceScore != null
        ? (resilienceScore! / 100.0).clamp(0.05, 1.0)
        : ((100.0 - (shotEfficiency * 0.5)) / 100.0).clamp(0.05, 1.0);
    final normalizedForm = (formRating / 100.0).clamp(0.05, 1.0);

    return AspectRatio(
      aspectRatio: 1.05,
      child: CustomPaint(
        painter: RadarChartPainter(
          values: [
            normalizedShots,
            normalizedPasses,
            normalizedPossession,
            normalizedDefending,
            normalizedResilience,
            normalizedForm,
          ],
          labels: [
            'ATTACK',
            'PASSING',
            'POSSESSION',
            'DEFENDING',
            'RESILIENCE',
            'FORM',
          ],
          color: primaryColor ?? AppColors.cyan,
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
    final radius = min(center.dx, center.dy) * 0.68;
    final angle = 2 * pi / values.length;

    // Draw background concentric polygon web
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

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

    // Draw radial axes and glowing labels
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    for (var i = 0; i < values.length; i++) {
      final x = center.dx + radius * cos(i * angle - pi / 2);
      final y = center.dy + radius * sin(i * angle - pi / 2);
      canvas.drawLine(center, Offset(x, y), axisPaint);

      // Value percentage badge text
      final valPct = (values[i] * 100).round();
      final labelSpan = TextSpan(
        children: [
          TextSpan(
            text: '${labels[i]}\n',
            style: GoogleFonts.rajdhani(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          TextSpan(
            text: '$valPct',
            style: GoogleFonts.orbitron(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
      final textPainter = TextPainter(
        text: labelSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      const labelOffset = 22.0;
      final lx = center.dx + (radius + labelOffset) * cos(i * angle - pi / 2) - textPainter.width / 2;
      final ly = center.dy + (radius + labelOffset) * sin(i * angle - pi / 2) - textPainter.height / 2;
      textPainter.paint(canvas, Offset(lx, ly));
    }

    // Draw gradient filled data polygon
    final dataPaint = Paint()
      ..color = color.withValues(alpha: 0.30)
      ..style = PaintingStyle.fill;

    final dataOutlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final dotCenterPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dataPath = Path();
    final points = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final valRadius = radius * values[i].clamp(0.05, 1.0);
      final x = center.dx + valRadius * cos(i * angle - pi / 2);
      final y = center.dy + valRadius * sin(i * angle - pi / 2);
      final pt = Offset(x, y);
      points.add(pt);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();

    canvas.drawPath(dataPath, dataPaint);
    canvas.drawPath(dataPath, dataOutlinePaint);

    // Draw glowing data points
    for (final pt in points) {
      canvas.drawCircle(pt, 4.0, dotPaint);
      canvas.drawCircle(pt, 2.0, dotCenterPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Integrated Dual-Player Radar Chart for H2H Rivalry
// ─────────────────────────────────────────────────────────────────────────────

class H2hDualRadarChart extends StatelessWidget {
  final String p1Name;
  final String p2Name;
  final Map<String, dynamic> p1Stats;
  final Map<String, dynamic> p2Stats;
  final String? title;
  final String? subtitle;

  const H2hDualRadarChart({
    super.key,
    required this.p1Name,
    required this.p2Name,
    required this.p1Stats,
    required this.p2Stats,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final p1Poss = ((p1Stats['possession'] as num?)?.toDouble() ?? 50.0) / 100.0;
    final p1Pass = ((p1Stats['passing'] as num?)?.toDouble() ?? 75.0) / 100.0;
    final p1Shot = ((p1Stats['shooting'] as num?)?.toDouble() ?? 50.0) / 100.0;
    final p1Def  = ((p1Stats['defending'] as num?)?.toDouble() ?? 60.0) / 100.0;
    final p1Form = ((p1Stats['form'] as num?)?.toDouble() ?? 50.0) / 100.0;

    final p2Poss = ((p2Stats['possession'] as num?)?.toDouble() ?? 50.0) / 100.0;
    final p2Pass = ((p2Stats['passing'] as num?)?.toDouble() ?? 75.0) / 100.0;
    final p2Shot = ((p2Stats['shooting'] as num?)?.toDouble() ?? 50.0) / 100.0;
    final p2Def  = ((p2Stats['defending'] as num?)?.toDouble() ?? 60.0) / 100.0;
    final p2Form = ((p2Stats['form'] as num?)?.toDouble() ?? 50.0) / 100.0;

    return GlassCard(
      gradientColors: [AppColors.surfaceLight, AppColors.surface],
      borderColor: AppColors.cyan.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radar, color: AppColors.cyan, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title ?? 'PERFORMANCE RADAR',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subtitle!,
                    style: GoogleFonts.rajdhani(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cyan,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(p1Name, AppColors.primary),
              const SizedBox(width: 24),
              _buildLegend(p2Name, AppColors.cyan),
            ],
          ),
          const SizedBox(height: 16),

          // Integrated Dual Radar Chart
          SizedBox(
            height: 250,
            child: CustomPaint(
              size: Size.infinite,
              painter: DualRadarChartPainter(
                p1Values: [p1Poss, p1Pass, p1Shot, p1Def, p1Form],
                p2Values: [p2Poss, p2Pass, p2Shot, p2Def, p2Form],
                labels: ['Possession', 'Passing', 'Shooting', 'Defending', 'Form'],
                p1Color: AppColors.primary,
                p2Color: AppColors.cyan,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Detailed Stat Comparison Matrix
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                _buildStatRow('Possession', '${(p1Poss * 100).toStringAsFixed(1)}%', '${(p2Poss * 100).toStringAsFixed(1)}%', p1Poss > p2Poss),
                const Divider(color: Colors.white10, height: 12),
                _buildStatRow('Passing Accuracy', '${(p1Pass * 100).toStringAsFixed(1)}%', '${(p2Pass * 100).toStringAsFixed(1)}%', p1Pass > p2Pass),
                const Divider(color: Colors.white10, height: 12),
                _buildStatRow('Shooting Acc.', '${(p1Shot * 100).toStringAsFixed(1)}%', '${(p2Shot * 100).toStringAsFixed(1)}%', p1Shot > p2Shot),
                const Divider(color: Colors.white10, height: 12),
                _buildStatRow('Defending Score', (p1Def * 100).toStringAsFixed(0), (p2Def * 100).toStringAsFixed(0), p1Def > p2Def),
                const Divider(color: Colors.white10, height: 12),
                _buildStatRow('Form Index', (p1Form * 100).toStringAsFixed(0), (p2Form * 100).toStringAsFixed(0), p1Form > p2Form),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String name, Color color) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              style: GoogleFonts.rajdhani(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String val1, String val2, bool p1Higher) {
    final isDraw = val1 == val2;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            val1,
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDraw ? Colors.white70 : (p1Higher ? AppColors.primary : Colors.white60),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            val2,
            textAlign: TextAlign.right,
            style: GoogleFonts.orbitron(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDraw ? Colors.white70 : (!p1Higher ? AppColors.cyan : Colors.white60),
            ),
          ),
        ),
      ],
    );
  }
}

class DualRadarChartPainter extends CustomPainter {
  final List<double> p1Values;
  final List<double> p2Values;
  final List<String> labels;
  final Color p1Color;
  final Color p2Color;

  DualRadarChartPainter({
    required this.p1Values,
    required this.p2Values,
    required this.labels,
    required this.p1Color,
    required this.p2Color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(center.dx, center.dy) * 0.70;
    final angle = 2 * pi / labels.length;

    // Draw background concentric polygon webs
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i <= 4; i++) {
      final r = radius * (i / 4);
      final path = Path();
      for (var j = 0; j < labels.length; j++) {
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

    // Draw radial axes & labels
    for (var i = 0; i < labels.length; i++) {
      final x = center.dx + radius * cos(i * angle - pi / 2);
      final y = center.dy + radius * sin(i * angle - pi / 2);
      canvas.drawLine(center, Offset(x, y), gridPaint);

      final labelSpan = TextSpan(
        style: GoogleFonts.rajdhani(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
        text: labels[i],
      );
      final textPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      const labelOffset = 22.0;
      final lx = center.dx + (radius + labelOffset) * cos(i * angle - pi / 2) - textPainter.width / 2;
      final ly = center.dy + (radius + labelOffset) * sin(i * angle - pi / 2) - textPainter.height / 2;
      textPainter.paint(canvas, Offset(lx, ly));
    }

    // Draw Player 2 Polygon (Cyan)
    _drawPolygon(canvas, center, radius, angle, p2Values, p2Color);

    // Draw Player 1 Polygon (Primary / Amber)
    _drawPolygon(canvas, center, radius, angle, p1Values, p1Color);
  }

  void _drawPolygon(Canvas canvas, Offset center, double radius, double angle, List<double> values, Color color) {
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final points = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final valRadius = radius * values[i].clamp(0.05, 1.0);
      final x = center.dx + valRadius * cos(i * angle - pi / 2);
      final y = center.dy + valRadius * sin(i * angle - pi / 2);
      final pt = Offset(x, y);
      points.add(pt);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    for (final pt in points) {
      canvas.drawCircle(pt, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant DualRadarChartPainter oldDelegate) {
    return oldDelegate.p1Values != p1Values ||
        oldDelegate.p2Values != p2Values ||
        oldDelegate.p1Color != p1Color ||
        oldDelegate.p2Color != p2Color;
  }
}
