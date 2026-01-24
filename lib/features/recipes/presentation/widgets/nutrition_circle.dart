import 'dart:math';
import 'package:flutter/material.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';

class NutritionCircle extends StatelessWidget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double size;

  const NutritionCircle({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    // Determine macro ratios
    // Standard rough assumption: 4cal/g for protein/carbs, 9cal/g for fat
    // Or just visualize grams ratio if that's what the user prefers.
    // Let's stick to grams ratio for the circle segments as it's cleaner visualization of mass.

    final total = protein + carbs + fat;
    final validTotal = total > 0 ? total : 1.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The Circle Chart
          CustomPaint(
            size: Size(size, size),
            painter: _MacroPainter(
              proteinPct: protein / validTotal,
              carbsPct: carbs / validTotal,
              fatPct: fat / validTotal,
              thickness: 12,
            ),
          ),
          // Center Text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${calories.round()}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              const Text(
                "Cal",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroPainter extends CustomPainter {
  final double proteinPct;
  final double carbsPct;
  final double fatPct;
  final double thickness;

  _MacroPainter({
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - thickness) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    // Draw background circle
    canvas.drawCircle(center, radius, bgPaint);

    if (proteinPct == 0 && carbsPct == 0 && fatPct == 0) return;

    double startAngle = -pi / 2; // Start from top

    // Protein (Green/Lime)
    _drawSegment(canvas, rect, startAngle, proteinPct, AppColors.zestyLime);
    startAngle += proteinPct * 2 * pi;

    // Carbs (Blue/White)
    _drawSegment(canvas, rect, startAngle, carbsPct, AppColors.electricBlue);
    startAngle += carbsPct * 2 * pi;

    // Fat (Yellow/Orange)
    _drawSegment(canvas, rect, startAngle, fatPct, const Color(0xFFFFC107));
  }

  void _drawSegment(
      Canvas canvas, Rect rect, double startAngle, double pct, Color color) {
    if (pct <= 0) return;
    final sweepAngle = pct * 2 * pi;
    // Add small gap if generally multiple segments
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
