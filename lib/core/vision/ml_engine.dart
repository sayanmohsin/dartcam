import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/constants/dartboard_constants.dart';

// ---------- DATA CLASSES ----------

class YoloBox {
  const YoloBox(this.x, this.y, this.w, this.h, this.score, this.classId);

  final double x;
  final double y;
  final double w;
  final double h;
  final double score;
  final int classId;
}

class MLResult {
  const MLResult({
    required this.dartTips,
    required this.calibrationPoints,
  });

  final List<Offset> dartTips;
  final List<Offset> calibrationPoints;

  bool get hasAllCalibrationPoints => calibrationPoints.length == 4;
  bool get hasDartTips => dartTips.isNotEmpty;
}

// ---------- TOP-LEVEL FUNCTION FOR ISOLATE ----------

MLResult? _processDetection(Uint8List imageBytes, IsolateInterpreter interpreter) {
  try {
    final image = img.decodeImage(imageBytes);
    if (image == null) return null;

    final resized = img.copyResize(image, width: 800, height: 800);

    final input = List.generate(
      1,
      (_) => List.generate(
        800,
        (y) => List.generate(
          800,
          (x) => [
            resized.getPixel(x, y).r / 255.0,
            resized.getPixel(x, y).g / 255.0,
            resized.getPixel(x, y).b / 255.0,
          ],
        ),
      ),
    );

    final output1 = List.generate(1, (_) =>
        List.generate(50, (_) =>
            List.generate(50, (_) =>
                List<double>.filled(30, 0))));
    final output2 = List.generate(1, (_) =>
        List.generate(25, (_) =>
            List.generate(25, (_) =>
                List<double>.filled(30, 0))));

    interpreter.runForMultipleInputs([input], {0: output1, 1: output2});

    final allBoxes = <YoloBox>[];
    allBoxes.addAll(decodeOutput(output1, 16, _anchorsStride16));
    allBoxes.addAll(decodeOutput(output2, 32, _anchorsStride32));

    final nmsBoxes = nms(allBoxes, 0.45);
    return extractKeypoints(nmsBoxes);
  } catch (e, st) {
    print('MLEngine._processDetection error: $e');
    print(st);
    return null;
  }
}

// ---------- INFERENCE ENGINE ----------

class MLEngine {
  MLEngine._();

  static Interpreter? _interpreter;
  static IsolateInterpreter? _isolateInterpreter;
  static bool _isLoaded = false;

  static bool get isLoaded => _isLoaded;

  // ---------- MODEL LIFECYCLE ----------

  static Future<void> loadModel() async {
    if (_isLoaded) return;
    _interpreter = await Interpreter.fromAsset(
      'assets/models/deepdarts_d2.tflite',
    );
    _isolateInterpreter = await IsolateInterpreter.create(
      address: _interpreter!.address,
    );
    _isLoaded = true;
  }

  static void close() {
    _isolateInterpreter?.close();
    _isolateInterpreter = null;
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }

  // ---------- INFERENCE ----------

  static Future<MLResult?> detect(Uint8List imageBytes) async {
    if (!_isLoaded || _isolateInterpreter == null) return null;
    return _processDetection(imageBytes, _isolateInterpreter!);
  }
}

// ---------- YOLOV4-TINY DECODING ----------

List<YoloBox> decodeOutput(
  List<List<List<List<double>>>> rawOutput,
  int stride,
  List<List<int>> anchors,
) {
  final boxes = <YoloBox>[];
  final gh = rawOutput[0].length;
  final gw = rawOutput[0][0].length;

  for (int a = 0; a < 3; a++) {
    for (int gy = 0; gy < gh; gy++) {
      for (int gx = 0; gx < gw; gx++) {
        final cell = rawOutput[0][gy][gx];
        final offset = a * 10;

        final tx = sigmoid(cell[offset]);
        final ty = sigmoid(cell[offset + 1]);
        final tw = cell[offset + 2];
        final th = cell[offset + 3];
        final obj = sigmoid(cell[offset + 4]);

        double bestScore = 0;
        int bestClass = 0;
        for (int c = 0; c < 5; c++) {
          final score = sigmoid(cell[offset + 5 + c]) * obj;
          if (score > bestScore) {
            bestScore = score;
            bestClass = c;
          }
        }

        if (bestScore < DartboardConstants.detectionConfThreshold) continue;

        final bx = (gx + tx) / gw;
        final by = (gy + ty) / gh;
        final bw = anchors[a][0] * exp(tw.clamp(-5, 5)) / 800;
        final bh = anchors[a][1] * exp(th.clamp(-5, 5)) / 800;

        boxes.add(YoloBox(bx, by, bw, bh, bestScore, bestClass));
      }
    }
  }

  return boxes;
}

// ---------- NON-MAXIMUM SUPPRESSION ----------

List<YoloBox> nms(List<YoloBox> boxes, double iouThreshold) {
  if (boxes.isEmpty) return [];

  final output = <YoloBox>[];

  for (int classId = 0; classId < 5; classId++) {
    final classBoxes = boxes.where((b) => b.classId == classId).toList();
    classBoxes.sort((a, b) => b.score.compareTo(a.score));

    final remaining = List<YoloBox>.from(classBoxes);
    while (remaining.isNotEmpty) {
      final best = remaining.removeAt(0);
      output.add(best);

      remaining.removeWhere(
        (box) => computeIoU(best, box) >= iouThreshold,
      );
    }
  }

  return output;
}

double computeIoU(YoloBox a, YoloBox b) {
  final aLeft = a.x - a.w / 2;
  final aTop = a.y - a.h / 2;
  final aRight = a.x + a.w / 2;
  final aBottom = a.y + a.h / 2;

  final bLeft = b.x - b.w / 2;
  final bTop = b.y - b.h / 2;
  final bRight = b.x + b.w / 2;
  final bBottom = b.y + b.h / 2;

  final interLeft = max(aLeft, bLeft);
  final interTop = max(aTop, bTop);
  final interRight = min(aRight, bRight);
  final interBottom = min(aBottom, bBottom);

  final interArea = max(0, interRight - interLeft) *
      max(0, interBottom - interTop);
  final unionArea = a.w * a.h + b.w * b.h - interArea;

  return unionArea > 0 ? interArea / unionArea : 0;
}

// ---------- KEYPOINT EXTRACTION ----------

MLResult extractKeypoints(List<YoloBox> boxes) {
  final dartTips = <Offset>[];
  final calibrationPoints = List<Offset?>.filled(4, null);

  for (final box in boxes) {
    if (box.classId == 0 && dartTips.length < 3) {
      dartTips.add(Offset(box.x, box.y));
    } else if (box.classId >= 1 && box.classId <= 4) {
      final idx = box.classId - 1;
      if (calibrationPoints[idx] == null) {
        calibrationPoints[idx] = Offset(box.x, box.y);
      }
    }
  }

  return MLResult(
    dartTips: dartTips,
    calibrationPoints: calibrationPoints.whereType<Offset>().toList(),
  );
}

// ---------- MATH HELPERS ----------

double sigmoid(double x) {
  return 1.0 / (1.0 + exp(-x.clamp(-88, 88)));
}

// ---------- ANCHORS ----------

const _anchorsStride16 = [
  [81, 82],
  [135, 169],
  [344, 319],
];

const _anchorsStride32 = [
  [23, 27],
  [37, 58],
  [81, 82],
];
