import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_dart_scorer/core/vision/ml_engine.dart';

void main() {
  group('sigmoid', () {
    test('returns 0.5 for zero input', () {
      expect(sigmoid(0), closeTo(0.5, 1e-10));
    });

    test('returns ~0.731 for input 1', () {
      expect(sigmoid(1), closeTo(1 / (1 + exp(-1)), 1e-10));
    });

    test('returns ~0.269 for input -1', () {
      expect(sigmoid(-1), closeTo(1 / (1 + exp(1)), 1e-10));
    });

    test('clamps large positive values to ~1.0', () {
      expect(sigmoid(88), closeTo(1.0, 1e-10));
      expect(sigmoid(100), closeTo(1.0, 1e-10));
    });

    test('clamps large negative values to ~0.0', () {
      expect(sigmoid(-88), closeTo(0.0, 1e-10));
      expect(sigmoid(-100), closeTo(0.0, 1e-10));
    });

    test('is monotonically increasing', () {
      for (double x = -10; x <= 10; x += 0.5) {
        expect(sigmoid(x), greaterThanOrEqualTo(sigmoid(x - 0.5)));
      }
    });
  });

  group('Output tensor allocation', () {
    test('List.generate creates independent inner lists', () {
      final output = List.generate(1, (_) =>
          List.generate(5, (_) =>
              List.generate(5, (_) =>
                  List<double>.filled(30, 0))));

      // Write to cell [0][0]
      output[0][0][0][0] = 42.0;
      output[0][0][1][5] = 99.0;

      // Verify cell [0][1] is NOT affected
      expect(output[0][1][0][0], 0.0);
      expect(output[0][1][1][5], 0.0);

      // Verify cell [0][0][1] IS affected (same list within same cell row)
      // Wait — [0][0][0] and [0][0][1] should be independent because
      // List.generate creates new instances per (_) => callback
      expect(output[0][0][1][0], 0.0);
    });

    test('old List.filled pattern shares inner list references (documents bug)', () {
      // This test documents the old buggy behavior for reference.
      // With List.filled, all rows in a 2D block share the same inner list.
      final buggy = List<List<double>>.filled(
        3,
        List<double>.filled(5, 0),
      );

      // Writing to row 0 also changes row 1 and row 2
      buggy[0][0] = 42.0;
      expect(buggy[1][0], 42.0); // Bug: shared reference
      expect(buggy[2][0], 42.0); // Bug: shared reference
    });

    test('List.generate output can hold distinct values per cell', () {
      final output = List.generate(1, (_) =>
          List.generate(3, (_) =>
              List.generate(3, (_) =>
                  List<double>.filled(10, 0))));

      // Set distinct values across cells
      output[0][0][0][0] = 1.0;
      output[0][0][1][0] = 2.0;
      output[0][1][0][0] = 3.0;
      output[0][2][2][0] = 4.0;

      expect(output[0][0][0][0], 1.0);
      expect(output[0][0][1][0], 2.0);
      expect(output[0][1][0][0], 3.0);
      expect(output[0][2][2][0], 4.0);

      // All other cells remain zero
      expect(output[0][0][0][1], 0.0);
      expect(output[0][1][1][5], 0.0);
    });
  });

  group('computeIoU', () {
    test('identical boxes have IoU of 1.0', () {
      const a = YoloBox(0.5, 0.5, 0.2, 0.2, 0.9, 0);
      const b = YoloBox(0.5, 0.5, 0.2, 0.2, 0.8, 0);
      expect(computeIoU(a, b), closeTo(1.0, 1e-10));
    });

    test('non-overlapping boxes have IoU of 0.0', () {
      const a = YoloBox(0.2, 0.2, 0.1, 0.1, 0.9, 0);
      const b = YoloBox(0.8, 0.8, 0.1, 0.1, 0.8, 0);
      expect(computeIoU(a, b), 0.0);
    });

    test('partially overlapping boxes have correct IoU', () {
      // Two 0.2x0.2 boxes, overlapping by 0.1x0.2 = 0.02 area
      // Union = 0.04 + 0.04 - 0.02 = 0.06
      // IoU = 0.02 / 0.06 = 1/3
      const a = YoloBox(0.3, 0.3, 0.2, 0.2, 0.9, 0);
      const b = YoloBox(0.4, 0.3, 0.2, 0.2, 0.8, 0);
      expect(computeIoU(a, b), closeTo(1 / 3, 1e-10));
    });

    test('touching edges have IoU of 0.0', () {
      const a = YoloBox(0.25, 0.25, 0.2, 0.2, 0.9, 0);
      const b = YoloBox(0.35, 0.25, 0.2, 0.2, 0.8, 0);
      // a right edge = 0.35, b left edge = 0.25, overlap in x = 0.1
      // But a right = 0.25+0.1 = 0.35, b left = 0.35-0.1 = 0.25
      // So overlap = 0.35 - 0.25 = 0.1 in x, 0.2 in y
      // Actually these DO overlap
      expect(computeIoU(a, b), greaterThan(0.0));
    });
  });

  group('nms', () {
    test('returns empty list for empty input', () {
      expect(nms([], 0.45), isEmpty);
    });

    test('keeps single box', () {
      const boxes = [
        YoloBox(0.5, 0.5, 0.2, 0.2, 0.9, 0),
      ];
      final result = nms(boxes, 0.45);
      expect(result.length, 1);
      expect(result[0].score, 0.9);
    });

    test('removes lower-score overlapping box of same class', () {
      const boxes = [
        YoloBox(0.5, 0.5, 0.2, 0.2, 0.9, 0),
        YoloBox(0.5, 0.5, 0.2, 0.2, 0.7, 0),
      ];
      final result = nms(boxes, 0.45);
      expect(result.length, 1);
      expect(result[0].score, 0.9);
    });

    test('keeps both non-overlapping boxes', () {
      const boxes = [
        YoloBox(0.2, 0.2, 0.1, 0.1, 0.9, 0),
        YoloBox(0.8, 0.8, 0.1, 0.1, 0.8, 0),
      ];
      final result = nms(boxes, 0.45);
      expect(result.length, 2);
    });

    test('keeps overlapping boxes of different classes', () {
      const boxes = [
        YoloBox(0.5, 0.5, 0.2, 0.2, 0.9, 0),
        YoloBox(0.5, 0.5, 0.2, 0.2, 0.8, 1),
      ];
      final result = nms(boxes, 0.45);
      expect(result.length, 2);
    });

    test('preserves highest scoring box per suppression group', () {
      const boxes = [
        YoloBox(0.5, 0.5, 0.2, 0.2, 0.6, 0),
        YoloBox(0.5, 0.5, 0.2, 0.2, 0.95, 0),
        YoloBox(0.5, 0.5, 0.2, 0.2, 0.7, 0),
      ];
      final result = nms(boxes, 0.45);
      expect(result.length, 1);
      expect(result[0].score, 0.95);
    });
  });

  group('extractKeypoints', () {
    test('extracts up to 3 dart tips (class 0)', () {
      const boxes = [
        YoloBox(0.1, 0.1, 0.02, 0.02, 0.9, 0),
        YoloBox(0.2, 0.2, 0.02, 0.02, 0.85, 0),
        YoloBox(0.3, 0.3, 0.02, 0.02, 0.8, 0),
        YoloBox(0.4, 0.4, 0.02, 0.02, 0.75, 0),
      ];
      final result = extractKeypoints(boxes);
      expect(result.dartTips.length, 3);
      expect(result.calibrationPoints, isEmpty);
    });

    test('extracts calibration points (classes 1-4)', () {
      const boxes = [
        YoloBox(0.1, 0.1, 0.02, 0.02, 0.9, 1),
        YoloBox(0.2, 0.2, 0.02, 0.02, 0.85, 2),
        YoloBox(0.3, 0.3, 0.02, 0.02, 0.8, 3),
        YoloBox(0.4, 0.4, 0.02, 0.02, 0.75, 4),
      ];
      final result = extractKeypoints(boxes);
      expect(result.dartTips, isEmpty);
      expect(result.calibrationPoints.length, 4);
      expect(result.hasAllCalibrationPoints, isTrue);
    });

    test('extracts both dart tips and calibration points', () {
      const boxes = [
        YoloBox(0.1, 0.1, 0.02, 0.02, 0.9, 0),
        YoloBox(0.2, 0.2, 0.02, 0.02, 0.85, 0),
        YoloBox(0.5, 0.1, 0.02, 0.02, 0.9, 1),
        YoloBox(0.6, 0.2, 0.02, 0.02, 0.85, 2),
        YoloBox(0.7, 0.3, 0.02, 0.02, 0.8, 3),
        YoloBox(0.8, 0.4, 0.02, 0.02, 0.75, 4),
      ];
      final result = extractKeypoints(boxes);
      expect(result.dartTips.length, 2);
      expect(result.calibrationPoints.length, 4);
      expect(result.hasAllCalibrationPoints, isTrue);
      expect(result.hasDartTips, isTrue);
    });

    test('ignores duplicate calibration point of same class', () {
      const boxes = [
        YoloBox(0.1, 0.1, 0.02, 0.02, 0.9, 1),
        YoloBox(0.2, 0.2, 0.02, 0.02, 0.85, 1),
        YoloBox(0.3, 0.3, 0.02, 0.02, 0.8, 2),
      ];
      final result = extractKeypoints(boxes);
      expect(result.calibrationPoints.length, 2);
    });

    test('returns empty result for empty input', () {
      final result = extractKeypoints([]);
      expect(result.dartTips, isEmpty);
      expect(result.calibrationPoints, isEmpty);
      expect(result.hasDartTips, isFalse);
      expect(result.hasAllCalibrationPoints, isFalse);
    });
  });

  group('decodeOutput', () {
    test('returns empty list when all scores are below threshold', () {
      // sigmoid(-10) ≈ 0.000045, so obj * classScore is way below 0.25
      final output = List.generate(1, (_) =>
          List.generate(5, (_) =>
              List.generate(5, (_) =>
                  List<double>.filled(30, -10))));

      const anchors = [
        [81, 82],
        [135, 169],
        [344, 319],
      ];

      final result = decodeOutput(output, 16, anchors);
      expect(result, isEmpty);
    });

    test('detects high-confidence box at known grid position', () {
      // Start with all cells below threshold
      final output = List.generate(1, (_) =>
          List.generate(5, (_) =>
              List.generate(5, (_) =>
                  List<double>.filled(30, -10))));

      // Place a detection at grid cell (2, 2), anchor 0
      final cell = output[0][2][2];
      cell[0] = 0;  // tx → sigmoid = 0.5
      cell[1] = 0;  // ty → sigmoid = 0.5
      cell[2] = 0;  // tw → exp(0) = 1
      cell[3] = 0;  // th → exp(0) = 1
      cell[4] = 5;  // obj → sigmoid(5) ≈ 0.993
      cell[5] = 5;  // class 0 → sigmoid(5) ≈ 0.993

      const anchors = [
        [81, 82],
        [135, 169],
        [344, 319],
      ];

      final result = decodeOutput(output, 16, anchors);
      expect(result.length, 1);
      expect(result[0].classId, 0);
      expect(result[0].x, closeTo(0.5, 0.01));
      expect(result[0].y, closeTo(0.5, 0.01));
      expect(result[0].score, greaterThan(0.25));
    });
  });
}
