import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/dartboard_constants.dart';
import 'manual_picker_grid.dart' show ManualPickerResult;

// Enlargement factors for easier tapping
const _bullFactor = 1.9;
const _ringFactor = 1.3;
const _snapAngleDeg = 2.0;

class DartboardPicker extends StatefulWidget {
  final void Function(ManualPickerResult?) onScore;

  const DartboardPicker({super.key, required this.onScore});

  @override
  State<DartboardPicker> createState() => _DartboardPickerState();
}

class _DartboardPickerState extends State<DartboardPicker>
    with SingleTickerProviderStateMixin {
  ManualPickerResult? _preview;
  bool _hasSelection = false;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
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

    // Enlarged miss boundary
    if (distanceMm > DartboardConstants.doubleOuterRadius * _ringFactor) {
      if (_hasSelection) {
        setState(() {
          _preview = null;
          _hasSelection = false;
        });
      } else {
        widget.onScore(null);
      }
      return;
    }

    final result = _scoreFromPolar(distanceMm, dx, dy);
    if (result != null) {
      HapticFeedback.lightImpact();
      setState(() {
        _preview = result;
        _hasSelection = true;
      });
      _glowController.forward(from: 0);
    }
  }

  ManualPickerResult? _scoreFromPolar(
    double distanceMm,
    double dx,
    double dy,
  ) {
    var angle = atan2(dx, -dy) * 180 / pi;
    var normalizedAngle = (angle + 360) % 360;

    // Snap to nearest number if within 2° of a wedge boundary
    final rawWedgeIndex = normalizedAngle / DartboardConstants.wedgeAngleDegrees;
    final frac = rawWedgeIndex - rawWedgeIndex.floor();
    int wedgeIndex;
    if (frac < _snapAngleDeg / DartboardConstants.wedgeAngleDegrees) {
      wedgeIndex = rawWedgeIndex.floor() % 20;
    } else if (frac > 1 - _snapAngleDeg / DartboardConstants.wedgeAngleDegrees) {
      wedgeIndex = (rawWedgeIndex.floor() + 1) % 20;
    } else {
      wedgeIndex = rawWedgeIndex.floor() % 20;
    }
    final score = DartboardConstants.wedgeValues[wedgeIndex];

    // Enlarged bull hit zones
    if (distanceMm <= DartboardConstants.bullseyeInnerRadius * _bullFactor) {
      return const ManualPickerResult(score: 50, multiplier: 1, label: 'BULL');
    }
    if (distanceMm <= DartboardConstants.bullseyeOuterRadius * _bullFactor) {
      return const ManualPickerResult(score: 25, multiplier: 1, label: '25');
    }

    // Enlarged ring hit zones
    final extTripleInner = DartboardConstants.tripleInnerRadius - (99 - 99 / _ringFactor);
    final extTripleOuter = DartboardConstants.tripleOuterRadius + (107 * _ringFactor - 107);
    final extDoubleInner = DartboardConstants.doubleInnerRadius - (162 - 162 / _ringFactor);
    final extDoubleOuter = DartboardConstants.doubleOuterRadius * _ringFactor;

    if (distanceMm >= extTripleInner && distanceMm <= extTripleOuter) {
      return ManualPickerResult(score: score, multiplier: 3, label: 'T$score');
    }
    if (distanceMm >= extDoubleInner && distanceMm <= extDoubleOuter) {
      return ManualPickerResult(score: score, multiplier: 2, label: 'D$score');
    }

    return ManualPickerResult(score: score, multiplier: 1, label: '$score');
  }

  void _confirm() {
    if (_preview != null) {
      widget.onScore(_preview);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111215),
      child: SafeArea(
        child: Column(
          children: [
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
                        child: _buildBoard(size),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_hasSelection && _preview != null)
              _buildConfirmationBar()
            else
              _buildMissButton(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(double size) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(size, size),
          painter: _DartboardPainter(
            preview: _preview,
            hasSelection: _hasSelection,
            glowProgress: _glowAnimation.value,
          ),
        );
      },
    );
  }

  Widget _buildConfirmationBar() {
    final label = _preview!.label;
    final totalScore = _preview!.score * _preview!.multiplier;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF6D00).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '= $totalScore',
            style: const TextStyle(
              color: Color(0xFFFF6D00),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _confirm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6D00),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ADD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _preview = null;
                _hasSelection = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF424242),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white70, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => widget.onScore(null),
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFF2A2A2A),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'MISS',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _DartboardPainter extends CustomPainter {
  final ManualPickerResult? preview;
  final bool hasSelection;
  final double glowProgress;

  _DartboardPainter({
    required this.preview,
    required this.hasSelection,
    required this.glowProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final boardRadius = size.width / 2;
    final mmPerPx = DartboardConstants.boardRadius / boardRadius;
    final numberRingRadius = boardRadius * 1.08;

    _drawBoard(canvas, center, boardRadius, mmPerPx);
    _drawWires(canvas, center, boardRadius, mmPerPx);

    if (hasSelection && preview != null) {
      _drawHighlight(canvas, size, center);
    }

    _drawNumbers(canvas, center, numberRingRadius);
  }

  void _drawHighlight(Canvas canvas, Size size, Offset center) {
    if (preview == null) return;

    final isBull = preview!.label == 'BULL' || preview!.label == '25';
    if (isBull) {
      _drawHighlightedBull(canvas, center, size);
      return;
    }

    final wedgeAngle = DartboardConstants.wedgeAngleDegrees * pi / 180;
    final wedgeIndex = DartboardConstants.wedgeValues
        .indexOf(preview!.score >= 0 && preview!.score <= 20 ? preview!.score : -1);
    if (wedgeIndex < 0) return;

    final boardRadius = size.width / 2;
    final mmPerPx = DartboardConstants.boardRadius / boardRadius;

    final startAngle = wedgeIndex * wedgeAngle - pi / 2 - wedgeAngle / 2;
    final endAngle = startAngle + wedgeAngle;

    final double innerRadius, outerRadius;
    switch (preview!.multiplier) {
      case 3:
        innerRadius = DartboardConstants.tripleInnerRadius / mmPerPx;
        outerRadius = DartboardConstants.tripleOuterRadius / mmPerPx;
      case 2:
        innerRadius = DartboardConstants.doubleInnerRadius / mmPerPx;
        outerRadius = DartboardConstants.doubleOuterRadius / mmPerPx;
      default:
        innerRadius = DartboardConstants.bullseyeOuterRadius / mmPerPx;
        outerRadius = DartboardConstants.doubleInnerRadius / mmPerPx;
    }

    final highlightPath = Path();
    highlightPath.moveTo(
      center.dx + innerRadius * cos(startAngle),
      center.dy + innerRadius * sin(startAngle),
    );
    highlightPath.arcTo(
      Rect.fromCircle(center: center, radius: innerRadius),
      startAngle,
      wedgeAngle,
      false,
    );
    highlightPath.lineTo(
      center.dx + outerRadius * cos(endAngle),
      center.dy + outerRadius * sin(endAngle),
    );
    highlightPath.arcTo(
      Rect.fromCircle(center: center, radius: outerRadius),
      endAngle,
      -wedgeAngle,
      false,
    );
    highlightPath.close();

    final fillPaint = Paint()
      ..color = const Color(0xFFFF6D00).withOpacity(0.25 * glowProgress);
    canvas.drawPath(highlightPath, fillPaint);

    final glowPaint = Paint()
      ..color = const Color(0xFFFF6D00).withOpacity(0.8 * glowProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(highlightPath, glowPaint);
  }

  void _drawHighlightedBull(Canvas canvas, Offset center, Size size) {
    if (preview == null) return;

    final boardRadius = size.width / 2;
    final mmPerPx = DartboardConstants.boardRadius / boardRadius;
    final radius = (preview!.score == 50
            ? DartboardConstants.bullseyeInnerRadius
            : DartboardConstants.bullseyeOuterRadius) /
        mmPerPx;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFFFF6D00).withOpacity(0.25 * glowProgress),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFFF6D00).withOpacity(0.8 * glowProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
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
        oldDelegate.hasSelection != hasSelection ||
        oldDelegate.glowProgress != glowProgress;
  }
}
