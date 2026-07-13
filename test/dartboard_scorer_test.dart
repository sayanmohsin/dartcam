import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_dart_scorer/core/vision/dartboard_scorer.dart';
import 'package:local_dart_scorer/core/constants/dartboard_constants.dart';

void main() {
  group('DartboardScorer.scoreDarts', () {
    /// Build calibration points that perfectly match the expected destination
    /// points so the homography is the identity transform.
    List<Offset> _perfectCalibrationPoints(Offset center, double radius) {
      return List.generate(4, (i) {
        final number = [20, 6, 3, 11][i];
        final idx = DartboardConstants.boardNumbers.indexOf('$number');
        final angleDeg = idx * 18.0 - 9.0;
        final angleRad = angleDeg * pi / 180;
        return Offset(
          center.dx + radius * cos(angleRad),
          center.dy - radius * sin(angleRad),
        );
      });
    }

    test('returns empty list when fewer than 4 calibration points', () {
      final result = DartboardScorer.scoreDarts(
        dartTips: [const Offset(100, 100)],
        calibrationPoints: [const Offset(0, 0), const Offset(100, 0)],
      );
      expect(result, isEmpty);
    });

    test('returns empty list when no dart tips provided', () {
      final cal = _perfectCalibrationPoints(
        const Offset(200, 200),
        150,
      );
      final result = DartboardScorer.scoreDarts(
        dartTips: [],
        calibrationPoints: cal,
      );
      expect(result, isEmpty);
    });

    test('scores double bull at board center', () {
      final center = const Offset(200, 200);
      const radius = 150.0;
      final cal = _perfectCalibrationPoints(center, radius);

      final result = DartboardScorer.scoreDarts(
        dartTips: [center],
        calibrationPoints: cal,
      );

      expect(result.length, 1);
      expect(result[0].score, 50);
      expect(result[0].multiplier, 1);
      expect(result[0].label, 'DB');
    });

    test('scores outer bull near center', () {
      final center = const Offset(200, 200);
      const radius = 150.0;
      final cal = _perfectCalibrationPoints(center, radius);

      // Place dart at bullseyeOuterRadius distance from center
      final dartPos = Offset(
        center.dx + DartboardConstants.bullseyeOuterRadius * 0.9,
        center.dy,
      );

      final result = DartboardScorer.scoreDarts(
        dartTips: [dartPos],
        calibrationPoints: cal,
      );

      expect(result.length, 1);
      expect(result[0].score, 25);
      expect(result[0].label, 'B');
    });

    test('scores miss outside board radius', () {
      final center = const Offset(200, 200);
      const radius = 150.0;
      final cal = _perfectCalibrationPoints(center, radius);

      // Place dart well outside the board
      final dartPos = Offset(
        center.dx + radius + 50,
        center.dy,
      );

      final result = DartboardScorer.scoreDarts(
        dartTips: [dartPos],
        calibrationPoints: cal,
      );

      expect(result.length, 1);
      expect(result[0].score, 0);
      expect(result[0].label, '0');
    });

    test('scores multiple darts in a single turn', () {
      final center = const Offset(200, 200);
      const radius = 150.0;
      final cal = _perfectCalibrationPoints(center, radius);

      // Place three darts at the center (all double bull)
      final result = DartboardScorer.scoreDarts(
        dartTips: [center, center, center],
        calibrationPoints: cal,
      );

      expect(result.length, 3);
      for (final dart in result) {
        expect(dart.score, 50);
        expect(dart.label, 'DB');
      }
    });
  });

  group('ScoredDart', () {
    test('totalScore computes score * multiplier', () {
      const dart = ScoredDart(score: 20, multiplier: 3, label: 'T20');
      expect(dart.totalScore, 60);
    });

    test('totalScore for single', () {
      const dart = ScoredDart(score: 15, multiplier: 1, label: '15');
      expect(dart.totalScore, 15);
    });

    test('totalScore for double', () {
      const dart = ScoredDart(score: 18, multiplier: 2, label: 'D18');
      expect(dart.totalScore, 36);
    });

    test('description for double bull', () {
      const dart = ScoredDart(score: 50, multiplier: 1, label: 'DB');
      expect(dart.description, 'Double Bull');
    });

    test('description for outer bull', () {
      const dart = ScoredDart(score: 25, multiplier: 1, label: 'B');
      expect(dart.description, 'Outer Bull');
    });

    test('description for double', () {
      const dart = ScoredDart(score: 20, multiplier: 2, label: 'D20');
      expect(dart.description, 'Double 20');
    });

    test('description for triple', () {
      const dart = ScoredDart(score: 20, multiplier: 3, label: 'T20');
      expect(dart.description, 'Triple 20');
    });

    test('description for single', () {
      const dart = ScoredDart(score: 7, multiplier: 1, label: '7');
      expect(dart.description, 'Single 7');
    });
  });
}
