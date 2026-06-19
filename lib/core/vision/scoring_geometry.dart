import 'dart:math';
import '../constants/dartboard_constants.dart';
import 'cv_engine.dart';
import 'board_detector.dart';

class ScoredDart {
  final int score;
  final int multiplier;
  final String label;

  const ScoredDart({
    required this.score,
    required this.multiplier,
    required this.label,
  });

  int get totalScore => score * multiplier;
}

class ScoringGeometry {
  ScoringGeometry._();

  static ScoredDart pixelToScore(
    DetectedPoint point,
    double boardCenterX,
    double boardCenterY,
    double pixelsPerMm,
  ) {
    final dx = point.x - boardCenterX;
    final dy = point.y - boardCenterY;
    final distancePx = sqrt(dx * dx + dy * dy);
    final distanceMm = distancePx / pixelsPerMm;

    var angle = atan2(dy, dx);
    var angleDeg = angle * (180 / pi);

    angleDeg = (angleDeg + 90) % 360;
    if (angleDeg < 0) angleDeg += 360;

    final wedgeIndex =
        (angleDeg / DartboardConstants.wedgeAngleDegrees).floor() % 20;
    final baseScore = DartboardConstants.wedgeValues[wedgeIndex];

    if (distanceMm <= DartboardConstants.bullseyeInnerRadius) {
      return const ScoredDart(score: 50, multiplier: 1, label: 'BULL');
    }

    if (distanceMm <= DartboardConstants.bullseyeOuterRadius) {
      return const ScoredDart(score: 25, multiplier: 1, label: '25');
    }

    if (distanceMm >= DartboardConstants.tripleInnerRadius &&
        distanceMm <= DartboardConstants.tripleOuterRadius) {
      return ScoredDart(
        score: baseScore,
        multiplier: 3,
        label: 'T$baseScore',
      );
    }

    if (distanceMm >= DartboardConstants.doubleInnerRadius &&
        distanceMm <= DartboardConstants.doubleOuterRadius) {
      return ScoredDart(
        score: baseScore,
        multiplier: 2,
        label: 'D$baseScore',
      );
    }

    return ScoredDart(
      score: baseScore,
      multiplier: 1,
      label: '$baseScore',
    );
  }

  static List<ScoredDart> scoreAllDarts(
    List<DetectedPoint> points,
    BoardCircle board,
  ) {
    final pixelsPerMm = board.radius / DartboardConstants.boardRadius;

    final validPoints = points.where((p) => board.contains(p.x, p.y)).toList();

    return validPoints.map((point) {
      return pixelToScore(
          point, board.centerX, board.centerY, pixelsPerMm);
    }).toList();
  }
}
