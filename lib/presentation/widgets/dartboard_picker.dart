import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/dartboard_constants.dart';
import 'manual_picker_grid.dart' show ManualPickerResult;

class DartboardPicker extends StatefulWidget {
  final void Function(ManualPickerResult?) onScore;
  final double? fixedSize;

  const DartboardPicker({super.key, required this.onScore, this.fixedSize});

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

    if (distanceMm > DartboardConstants.doubleOuterRadius + 5) {
      widget.onScore(null);
      return;
    }

    final result = _scoreFromPolar(distanceMm, dx, dy);
    if (result != null) {
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
    final angle = atan2(dx, -dy) * 180 / pi;
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

  @override
  Widget build(BuildContext context) {
    final hasFixedSize = widget.fixedSize != null;

    final content = Column(
      mainAxisSize: hasFixedSize ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (hasFixedSize) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTapUp: (details) => _handleTap(details, widget.fixedSize!),
            child: SizedBox(
              width: widget.fixedSize,
              height: widget.fixedSize,
              child: Stack(
                children: [
                  _buildBoard(widget.fixedSize!),
                  if (_hasSelection && _preview != null)
                    Positioned(
                      top: widget.fixedSize! * 0.08,
                      left: widget.fixedSize! * 0.25,
                      right: widget.fixedSize! * 0.25,
                      child: _buildPopover(widget.fixedSize!),
                    ),
                ],
              ),
            ),
          ),
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
        ] else ...[
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
                      child: Stack(
                        children: [
                          _buildBoard(size),
                          if (_hasSelection && _preview != null)
                            Positioned(
                              top: size * 0.08,
                              left: size * 0.25,
                              right: size * 0.25,
                              child: _buildPopover(size),
                            ),
                        ],
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
      ],
    );

    return Container(
      color: const Color(0xFF111215),
      child: hasFixedSize ? content : SafeArea(child: content),
    );
  }

  Widget _buildBoard(double size) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: _DartboardPainter(
            preview: _preview,
            hasSelection: _hasSelection,
            glowProgress: _glowAnimation.value,
          ),
        );
      },
    );
  }

  Widget _buildPopover(double boardSize) {
    final label = _preview!.label;
    final totalScore = _preview!.score * _preview!.multiplier;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFFF6D00).withOpacity(0.6),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$totalScore',
              style: const TextStyle(
                color: Color(0xFFFF6D00),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _confirm,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
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

    // Determine inner and outer radius based on multiplier
    // For singles: highlight the entire wedge (both outer and inner single bands)
    // For triples/doubles: highlight just that ring
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

    // Draw the highlighted area with a neon orange overlay
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
