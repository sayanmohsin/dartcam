import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/dartboard_constants.dart';
import 'manual_picker_grid.dart' show ManualPickerResult;

class DartboardPicker extends StatelessWidget {
  final void Function(ManualPickerResult?) onScore;

  const DartboardPicker({super.key, required this.onScore});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111215),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              'Tap the board to score',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = min(constraints.maxWidth, constraints.maxHeight) * 0.92;
                    return GestureDetector(
                      onTapUp: (details) => _handleTap(details, size),
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: CustomPaint(
                          painter: _DartboardPainter(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TextButton(
                onPressed: () => onScore(null),
                child: const Text(
                  'MISS',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(TapUpDetails details, double widgetSize) {
    final center = Offset(widgetSize / 2, widgetSize / 2);
    final tapPos = details.localPosition;

    final dx = tapPos.dx - center.dx;
    final dy = tapPos.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);

    final boardRadius = widgetSize / 2;
    final mmPerPx = DartboardConstants.boardRadius / boardRadius;
    final distanceMm = distance * mmPerPx;

    if (distanceMm > DartboardConstants.doubleOuterRadius + 5) {
      onScore(null);
      return;
    }

    final result = _scoreFromPolar(distanceMm, dx, dy, boardRadius);
    onScore(result);
  }

  ManualPickerResult? _scoreFromPolar(
    double distanceMm,
    double dx,
    double dy,
    double boardRadius,
  ) {
    final angle = atan2(-dx, -dy) * 180 / pi;
    final normalizedAngle = (angle + 360) % 360;
    final wedgeIndex = (normalizedAngle / DartboardConstants.wedgeAngleDegrees).floor() % 20;
    final score = DartboardConstants.wedgeValues[wedgeIndex];

    if (distanceMm <= DartboardConstants.bullseyeInnerRadius) {
      return const ManualPickerResult(score: 50, multiplier: 1, label: 'BULL');
    }
    if (distanceMm <= DartboardConstants.bullseyeOuterRadius) {
      return const ManualPickerResult(score: 25, multiplier: 1, label: '25');
    }
    if (distanceMm >= DartboardConstants.tripleInnerRadius &&
        distanceMm <= DartboardConstants.tripleOuterRadius) {
      return ManualPickerResult(score: score, multiplier: 3, label: 'T$score');
    }
    if (distanceMm >= DartboardConstants.doubleInnerRadius &&
        distanceMm <= DartboardConstants.doubleOuterRadius) {
      return ManualPickerResult(score: score, multiplier: 2, label: 'D$score');
    }
    return ManualPickerResult(score: score, multiplier: 1, label: '$score');
  }
}

class _DartboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final boardRadius = size.width / 2;
    final mmPerPx = DartboardConstants.boardRadius / boardRadius;

    final numberRingRadius = boardRadius * 1.08;

    _drawBoard(canvas, center, boardRadius, mmPerPx);
    _drawWires(canvas, center, boardRadius, mmPerPx);
    _drawNumbers(canvas, center, numberRingRadius);
  }

  void _drawBoard(
    Canvas canvas,
    Offset center,
    double boardRadius,
    double mmPerPx,
  ) {
    final wedgeAngle = DartboardConstants.wedgeAngleDegrees * pi / 180;

    for (int i = 0; i < 20; i++) {
      final startAngle = i * wedgeAngle - pi / 2 - wedgeAngle / 2;
      final endAngle = startAngle + wedgeAngle;

      final isEvenWedge = i % 2 == 0;
      final isRed = i % 2 == 0;

      // Outer single (bullseye to triple inner)
      _drawArcRing(
        canvas, center, startAngle, endAngle,
        DartboardConstants.bullseyeOuterRadius / mmPerPx,
        DartboardConstants.tripleInnerRadius / mmPerPx,
        isEvenWedge ? const Color(0xFFF5F0E1) : const Color(0xFF2D2D2D),
      );

      // Triple ring
      _drawArcRing(
        canvas, center, startAngle, endAngle,
        DartboardConstants.tripleInnerRadius / mmPerPx,
        DartboardConstants.tripleOuterRadius / mmPerPx,
        isRed ? const Color(0xFF006400) : const Color(0xFFC41E3A),
      );

      // Inner single (triple outer to double inner)
      _drawArcRing(
        canvas, center, startAngle, endAngle,
        DartboardConstants.tripleOuterRadius / mmPerPx,
        DartboardConstants.doubleInnerRadius / mmPerPx,
        isEvenWedge ? const Color(0xFFF5F0E1) : const Color(0xFF2D2D2D),
      );

      // Double ring
      _drawArcRing(
        canvas, center, startAngle, endAngle,
        DartboardConstants.doubleInnerRadius / mmPerPx,
        DartboardConstants.doubleOuterRadius / mmPerPx,
        isRed ? const Color(0xFFC41E3A) : const Color(0xFF006400),
      );
    }

    // Outer bull (red)
    canvas.drawCircle(
      center,
      DartboardConstants.bullseyeOuterRadius / mmPerPx,
      Paint()..color = const Color(0xFFC41E3A),
    );

    // Inner bull (green)
    canvas.drawCircle(
      center,
      DartboardConstants.bullseyeInnerRadius / mmPerPx,
      Paint()..color = const Color(0xFF006400),
    );
  }

  void _drawArcRing(
    Canvas canvas,
    Offset center,
    double startAngle,
    double endAngle,
    double innerRadius,
    double outerRadius,
    Color color,
  ) {
    final path = Path();
    path.moveTo(
      center.dx + innerRadius * cos(startAngle),
      center.dy + innerRadius * sin(startAngle),
    );
    path.arcTo(
      Rect.fromCircle(center: center, radius: innerRadius),
      startAngle,
      endAngle - startAngle,
      false,
    );
    path.lineTo(
      center.dx + outerRadius * cos(endAngle),
      center.dy + outerRadius * sin(endAngle),
    );
    path.arcTo(
      Rect.fromCircle(center: center, radius: outerRadius),
      endAngle,
      startAngle - endAngle,
      false,
    );
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawWires(
    Canvas canvas,
    Offset center,
    double boardRadius,
    double mmPerPx,
  ) {
    final wirePaint = Paint()
      ..color = const Color(0xFFB0B0B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final wedgeAngle = DartboardConstants.wedgeAngleDegrees * pi / 180;

    for (int i = 0; i < 20; i++) {
      final angle = i * wedgeAngle - pi / 2;
      canvas.drawLine(
        Offset(
          center.dx + DartboardConstants.bullseyeOuterRadius / mmPerPx * cos(angle),
          center.dy + DartboardConstants.bullseyeOuterRadius / mmPerPx * sin(angle),
        ),
        Offset(
          center.dx + DartboardConstants.doubleOuterRadius / mmPerPx * cos(angle),
          center.dy + DartboardConstants.doubleOuterRadius / mmPerPx * sin(angle),
        ),
        wirePaint,
      );
    }

    // Ring wires
    final ringRadii = [
      DartboardConstants.bullseyeInnerRadius,
      DartboardConstants.bullseyeOuterRadius,
      DartboardConstants.tripleInnerRadius,
      DartboardConstants.tripleOuterRadius,
      DartboardConstants.doubleInnerRadius,
      DartboardConstants.doubleOuterRadius,
    ];
    for (final radiusMm in ringRadii) {
      canvas.drawCircle(
        center,
        radiusMm / mmPerPx,
        wirePaint,
      );
    }
  }

  void _drawNumbers(
    Canvas canvas,
    Offset center,
    double numberRadius,
  ) {
    final wedgeAngle = DartboardConstants.wedgeAngleDegrees * pi / 180;
    final numbers = DartboardConstants.boardNumbers;

    for (int i = 0; i < 20; i++) {
      final angle = i * wedgeAngle - pi / 2;
      final x = center.dx + numberRadius * cos(angle);
      final y = center.dy + numberRadius * sin(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: numbers[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x - tp.width / 2, y - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
