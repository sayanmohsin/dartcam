import 'dart:math';
import 'dart:ui';

import '../../core/constants/dartboard_constants.dart';

// ---------- DATA CLASSES ----------

class ScoredDart {
  const ScoredDart({
    required this.score,
    required this.multiplier,
    required this.label,
  });

  final int score;
  final int multiplier;
  final String label;

  int get totalScore => score * multiplier;

  String get description {
    if (label == 'DB') return 'Double Bull';
    if (label == 'B') return 'Outer Bull';
    if (label.startsWith('D')) return 'Double ${label.substring(1)}';
    if (label.startsWith('T')) return 'Triple ${label.substring(1)}';
    return 'Single $label';
  }
}

// ---------- SCORING ENGINE ----------

class DartboardScorer {
  DartboardScorer._();

  static List<ScoredDart> scoreDarts({
    required List<Offset> dartTips,
    required List<Offset> calibrationPoints,
  }) {
    if (calibrationPoints.length < 4 || dartTips.isEmpty) return [];

    final center = _computeCenter(calibrationPoints);
    final radius = _computeRadius(calibrationPoints, center);
    final matrix = _computeTransform(calibrationPoints, center, radius);

    final scored = <ScoredDart>[];
    for (final dart in dartTips) {
      final relative = _applyTransform(matrix, dart, center);
      if (relative != null) {
        scored.add(_polarScore(relative, radius));
      } else {
        scored.add(const ScoredDart(score: 0, multiplier: 1, label: '0'));
      }
    }

    return scored;
  }

  // ---------- BOARD GEOMETRY ----------

  static Offset _computeCenter(List<Offset> points) {
    double x = 0;
    double y = 0;
    for (final p in points) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / points.length, y / points.length);
  }

  static double _computeRadius(List<Offset> points, Offset center) {
    double total = 0;
    for (final p in points) {
      total += (p - center).distance;
    }
    return total / points.length;
  }

  // ---------- PERSPECTIVE TRANSFORM ----------

  static List<List<double>> _computeTransform(
    List<Offset> srcPoints,
    Offset center,
    double radius,
  ) {
    final dstPoints = _destinationPoints(center, radius);
    return _computeHomography(srcPoints, dstPoints);
  }

  static List<Offset> _destinationPoints(Offset center, double radius) {
    return [
      _calPointPosition(20, center, radius),
      _calPointPosition(6, center, radius),
      _calPointPosition(3, center, radius),
      _calPointPosition(11, center, radius),
    ];
  }

  static Offset _calPointPosition(int number, Offset center, double radius) {
    final idx = DartboardConstants.boardNumbers.indexOf('$number');
    final angleDeg = idx * 18.0 - 9.0;
    final angleRad = angleDeg * pi / 180;

    return Offset(
      center.dx + radius * cos(angleRad),
      center.dy - radius * sin(angleRad),
    );
  }

  static Offset? _applyTransform(
    List<List<double>> matrix,
    Offset point,
    Offset center,
  ) {
    final x = point.dx - center.dx;
    final y = point.dy - center.dy;

    final w = matrix[2][0] * x + matrix[2][1] * y + matrix[2][2];
    if (w.abs() < 1e-10) return null;

    final hx = (matrix[0][0] * x + matrix[0][1] * y + matrix[0][2]) / w;
    final hy = (matrix[1][0] * x + matrix[1][1] * y + matrix[1][2]) / w;

    return Offset(hx, hy);
  }

  // ---------- POLAR SCORING ----------

  static ScoredDart _polarScore(Offset point, double boardRadius) {
    final distance = point.distance;

    if (distance > boardRadius) {
      return const ScoredDart(score: 0, multiplier: 1, label: '0');
    }

    if (distance <= DartboardConstants.bullseyeInnerRadius) {
      return const ScoredDart(score: 50, multiplier: 1, label: 'DB');
    }

    if (distance <= DartboardConstants.bullseyeOuterRadius) {
      return const ScoredDart(score: 25, multiplier: 1, label: 'B');
    }

    final angle = atan2(-point.dy, point.dx) * 180 / pi;
    final normalizedAngle = angle < 0 ? angle + 360 : angle;
    final wedgeIndex = (normalizedAngle / 18).floor() % 20;
    final number = int.parse(DartboardConstants.boardNumbers[wedgeIndex]);

    final scale = boardRadius / DartboardConstants.doubleOuterRadius;
    final trebleInner = DartboardConstants.tripleInnerRadius * scale;
    final trebleOuter = DartboardConstants.tripleOuterRadius * scale;
    final doubleInner = DartboardConstants.doubleInnerRadius * scale;

    if (distance >= doubleInner && distance <= boardRadius) {
      return ScoredDart(score: number, multiplier: 2, label: 'D$number');
    }

    if (distance >= trebleInner && distance <= trebleOuter) {
      return ScoredDart(score: number, multiplier: 3, label: 'T$number');
    }

    return ScoredDart(score: number, multiplier: 1, label: '$number');
  }

  // ---------- HOMOGRAPHY (DLT) ----------

  static List<List<double>> _computeHomography(
    List<Offset> src,
    List<Offset> dst,
  ) {
    final a = List<List<double>>.generate(8, (_) => List.filled(8, 0.0));
    final b = List.filled(8, 0.0);

    for (int i = 0; i < 4; i++) {
      final sx = src[i].dx;
      final sy = src[i].dy;
      final dx = dst[i].dx;
      final dy = dst[i].dy;

      a[i * 2] = [sx, sy, 1, 0, 0, 0, -dx * sx, -dx * sy];
      a[i * 2 + 1] = [0, 0, 0, sx, sy, 1, -dy * sx, -dy * sy];
      b[i * 2] = dx;
      b[i * 2 + 1] = dy;
    }

    final h = _solveLinearSystem(a, b);
    if (h == null) {
      return [
        [1, 0, 0],
        [0, 1, 0],
        [0, 0, 1],
      ];
    }

    return [
      [h[0], h[1], h[2]],
      [h[3], h[4], h[5]],
      [h[6], h[7], 1.0],
    ];
  }

  static List<double>? _solveLinearSystem(
    List<List<double>> a,
    List<double> b,
  ) {
    final n = b.length;
    final aug = List<List<double>>.generate(
      n,
      (i) => [...a[i], b[i]],
    );

    for (int col = 0; col < n; col++) {
      int maxRow = col;
      for (int row = col + 1; row < n; row++) {
        if (aug[row][col].abs() > aug[maxRow][col].abs()) {
          maxRow = row;
        }
      }
      final temp = aug[col];
      aug[col] = aug[maxRow];
      aug[maxRow] = temp;

      if (aug[col][col].abs() < 1e-10) return null;

      for (int row = col + 1; row < n; row++) {
        final factor = aug[row][col] / aug[col][col];
        for (int j = col; j <= n; j++) {
          aug[row][j] -= factor * aug[col][j];
        }
      }
    }

    final x = List.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      x[i] = aug[i][n];
      for (int j = i + 1; j < n; j++) {
        x[i] -= aug[i][j] * x[j];
      }
      x[i] /= aug[i][i];
    }

    return x;
  }
}
