import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/dartboard_constants.dart';
import 'manual_picker_grid.dart' show ManualPickerResult;

class DartboardPicker extends StatefulWidget {
  final void Function(ManualPickerResult?) onScore;

  const DartboardPicker({super.key, required this.onScore});

  @override
  State<DartboardPicker> createState() => _DartboardPickerState();
}

class _DartboardPickerState extends State<DartboardPicker>
    with SingleTickerProviderStateMixin {
  ManualPickerResult? _preview;
  bool _isZoomed = false;

  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _zoomAnimation = CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details, double widgetSize) {
    if (_isZoomed) return;

    final center = Offset(widgetSize / 2, widgetSize / 2);
    final tapPos = details.localPosition;

    final dx = tapPos.dx - center.dx;
    final dy = tapPos.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);

    final boardRadius = widgetSize / 2;
    final mmPerPx = DartboardConstants.boardRadius / boardRadius;
    final distanceMm = distance * mmPerPx;

    if (distanceMm > DartboardConstants.doubleOuterRadius + 5) {
      widget.onScore(null);
      return;
    }

    final result = _scoreFromPolar(distanceMm, dx, dy);
    if (result != null) {
      setState(() {
        _preview = result;
        _isZoomed = true;
      });
      _zoomController.forward(from: 0);
    }
  }

  ManualPickerResult? _scoreFromPolar(
    double distanceMm,
    double dx,
    double dy,
  ) {
    final angle = atan2(-dx, -dy) * 180 / pi;
    final normalizedAngle = (angle + 360) % 360;
    final wedgeIndex =
        (normalizedAngle / DartboardConstants.wedgeAngleDegrees).floor() % 20;
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

  void _confirm() {
    if (_preview != null) {
      widget.onScore(_preview);
    }
  }

  void _cancel() {
    _zoomController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _preview = null;
          _isZoomed = false;
        });
      }
    });
  }

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
                    final size =
                        min(constraints.maxWidth, constraints.maxHeight) * 0.92;
                    return GestureDetector(
                      onTapUp: (details) => _handleTap(details, size),
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: AnimatedBuilder(
                          animation: _zoomAnimation,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _DartboardPainter(
                                preview: _preview,
                                isZoomed: _isZoomed,
                                zoomProgress: _zoomAnimation.value,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_isZoomed && _preview != null) _buildConfirmBar(),
            if (!_isZoomed)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: TextButton(
                  onPressed: () => widget.onScore(null),
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

  Widget _buildConfirmBar() {
    final label = _preview!.label;
    final totalScore = _preview!.score * _preview!.multiplier;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6D00).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gps_fixed,
                    color: Color(0xFFFF6D00), size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$totalScore',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check_circle, size: 22),
                  label: Text('Confirm $label'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DartboardPainter extends CustomPainter {
  final ManualPickerResult? preview;
  final bool isZoomed;
  final double zoomProgress;

  _DartboardPainter({
    required this.preview,
    required this.isZoomed,
    required this.zoomProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final boardRadius = size.width / 2;
    final mmPerPx = DartboardConstants.boardRadius / boardRadius;

    if (isZoomed && preview != null) {
      _drawZoomedWedge(canvas, size, center);
    } else {
      final numberRingRadius = boardRadius * 1.08;
      _drawBoard(canvas, center, boardRadius, mmPerPx);
      _drawWires(canvas, center, boardRadius, mmPerPx);
      _drawNumbers(canvas, center, numberRingRadius);
    }
  }

  void _drawZoomedWedge(Canvas canvas, Size size, Offset center) {
    if (preview == null) return;

    final wedgeAngle = DartboardConstants.wedgeAngleDegrees * pi / 180;
    final wedgeIndex = DartboardConstants.wedgeValues
        .indexOf(preview!.score >= 0 && preview!.score <= 20 ? preview!.score : -1);

    final isBull = preview!.label == 'BULL' || preview!.label == '25';
    if (isBull) {
      _drawZoomedBull(canvas, size, center);
      return;
    }

    if (wedgeIndex < 0) return;

    final isEvenWedge = wedgeIndex % 2 == 0;

    final drawRadius = size.width * 0.38;
    final halfWedge = wedgeAngle / 2;

    final double innerRadius, outerRadius;
    final Color wedgeColor;

    switch (preview!.multiplier) {
      case 3:
        innerRadius = drawRadius * 0.55;
        outerRadius = drawRadius * 0.65;
        wedgeColor = isEvenWedge
            ? const Color(0xFF006400)
            : const Color(0xFFC41E3A);
      case 2:
        innerRadius = drawRadius * 0.88;
        outerRadius = drawRadius;
        wedgeColor = isEvenWedge
            ? const Color(0xFFC41E3A)
            : const Color(0xFF006400);
      default:
        if (preview!.score == 25) {
          innerRadius = drawRadius * 0.12;
          outerRadius = drawRadius * 0.22;
          wedgeColor = const Color(0xFFC41E3A);
        } else {
          innerRadius = drawRadius * 0.22;
          outerRadius = drawRadius * 0.55;
          wedgeColor = isEvenWedge
              ? const Color(0xFFF5F0E1)
              : const Color(0xFF2D2D2D);
        }
    }

    final startAngle = -pi / 2 - halfWedge;
    final endAngle = -pi / 2 + halfWedge;

    final path = Path();
    path.moveTo(
      center.dx + innerRadius * cos(startAngle),
      center.dy + innerRadius * sin(startAngle),
    );
    path.arcTo(
      Rect.fromCircle(center: center, radius: innerRadius),
      startAngle,
      wedgeAngle,
      false,
    );
    path.lineTo(
      center.dx + outerRadius * cos(endAngle),
      center.dy + outerRadius * sin(endAngle),
    );
    path.arcTo(
      Rect.fromCircle(center: center, radius: outerRadius),
      endAngle,
      -wedgeAngle,
      false,
    );
    path.close();

    canvas.drawPath(path, Paint()..color = wedgeColor);

    final glowPaint = Paint()
      ..color = const Color(0xFFFF6D00).withOpacity(0.6 * zoomProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(path, glowPaint);

    final label = preview!.label;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - 20,
      ),
    );

    final scorePainter = TextPainter(
      text: TextSpan(
        text: '${preview!.score * preview!.multiplier} pts',
        style: const TextStyle(
          color: Color(0xFFFF6D00),
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    scorePainter.paint(
      canvas,
      Offset(
        center.dx - scorePainter.width / 2,
        center.dy + 10,
      ),
    );
  }

  void _drawZoomedBull(Canvas canvas, Size size, Offset center) {
    final drawRadius = size.width * 0.35;

    final isDoubleBull = preview!.score == 50;
    final bullColor =
        isDoubleBull ? const Color(0xFF006400) : const Color(0xFFC41E3A);

    canvas.drawCircle(center, drawRadius, Paint()..color = bullColor);

    final glowPaint = Paint()
      ..color = const Color(0xFFFF6D00).withOpacity(0.6 * zoomProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, drawRadius, glowPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: preview!.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - 10,
      ),
    );

    final scorePainter = TextPainter(
      text: TextSpan(
        text: '${preview!.score * preview!.multiplier} pts',
        style: const TextStyle(
          color: Color(0xFFFF6D00),
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    scorePainter.paint(
      canvas,
      Offset(
        center.dx - scorePainter.width / 2,
        center.dy + 20,
      ),
    );
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

      _drawArcRing(
        canvas,
        center,
        startAngle,
        endAngle,
        DartboardConstants.bullseyeOuterRadius / mmPerPx,
        DartboardConstants.tripleInnerRadius / mmPerPx,
        isEvenWedge ? const Color(0xFFF5F0E1) : const Color(0xFF2D2D2D),
      );

      _drawArcRing(
        canvas,
        center,
        startAngle,
        endAngle,
        DartboardConstants.tripleInnerRadius / mmPerPx,
        DartboardConstants.tripleOuterRadius / mmPerPx,
        isEvenWedge ? const Color(0xFF006400) : const Color(0xFFC41E3A),
      );

      _drawArcRing(
        canvas,
        center,
        startAngle,
        endAngle,
        DartboardConstants.tripleOuterRadius / mmPerPx,
        DartboardConstants.doubleInnerRadius / mmPerPx,
        isEvenWedge ? const Color(0xFFF5F0E1) : const Color(0xFF2D2D2D),
      );

      _drawArcRing(
        canvas,
        center,
        startAngle,
        endAngle,
        DartboardConstants.doubleInnerRadius / mmPerPx,
        DartboardConstants.doubleOuterRadius / mmPerPx,
        isEvenWedge ? const Color(0xFFC41E3A) : const Color(0xFF006400),
      );
    }

    canvas.drawCircle(
      center,
      DartboardConstants.bullseyeOuterRadius / mmPerPx,
      Paint()..color = const Color(0xFFC41E3A),
    );

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
          center.dx +
              DartboardConstants.bullseyeOuterRadius / mmPerPx * cos(angle),
          center.dy +
              DartboardConstants.bullseyeOuterRadius / mmPerPx * sin(angle),
        ),
        Offset(
          center.dx +
              DartboardConstants.doubleOuterRadius / mmPerPx * cos(angle),
          center.dy +
              DartboardConstants.doubleOuterRadius / mmPerPx * sin(angle),
        ),
        wirePaint,
      );
    }

    final ringRadii = [
      DartboardConstants.bullseyeInnerRadius,
      DartboardConstants.bullseyeOuterRadius,
      DartboardConstants.tripleInnerRadius,
      DartboardConstants.tripleOuterRadius,
      DartboardConstants.doubleInnerRadius,
      DartboardConstants.doubleOuterRadius,
    ];
    for (final radiusMm in ringRadii) {
      canvas.drawCircle(center, radiusMm / mmPerPx, wirePaint);
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
  bool shouldRepaint(covariant _DartboardPainter oldDelegate) {
    return oldDelegate.preview != preview ||
        oldDelegate.isZoomed != isZoomed ||
        oldDelegate.zoomProgress != zoomProgress;
  }
}
