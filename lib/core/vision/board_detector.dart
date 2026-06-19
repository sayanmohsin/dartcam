import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../constants/dartboard_constants.dart';

class BoardCircle {
  final double centerX;
  final double centerY;
  final double radius;
  final BoardDetectionTier tier;

  const BoardCircle({
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.tier,
  });

  bool contains(double x, double y) {
    final dx = x - centerX;
    final dy = y - centerY;
    return dx * dx + dy * dy <= radius * radius;
  }
}

enum BoardDetectionTier {
  colorBased,
  brightnessBased,
  centerFallback,
}

class BoardDetector {
  BoardDetector._();

  static BoardCircle detectBoard(img.Image image, {Uint8List? referenceBytes}) {
    final width = image.width;
    final height = image.height;

    if (referenceBytes != null) {
      final refImage = img.decodeImage(referenceBytes);
      if (refImage != null) {
        final colorResult = _detectByColor(image, refImage);
        if (colorResult != null) return colorResult;
      }
    }

    final brightnessResult = _detectByBrightness(image);
    if (brightnessResult != null) return brightnessResult;

    final fallbackRadius =
        min(width, height) * DartboardConstants.centerFallbackRadiusRatio;
    return BoardCircle(
      centerX: width / 2,
      centerY: height / 2,
      radius: fallbackRadius,
      tier: BoardDetectionTier.centerFallback,
    );
  }

  static BoardCircle? _detectByColor(img.Image image, img.Image reference) {
    final width = image.width;
    final height = image.height;

    final sampleW = (width * DartboardConstants.centerSampleRatio).toInt();
    final sampleH = (height * DartboardConstants.centerSampleRatio).toInt();
    final startX = (width - sampleW) ~/ 2;
    final startY = (height - sampleH) ~/ 2;

    final mask = List.generate(
      height,
      (_) => List.filled(width, false),
    );

    int coloredPixels = 0;
    int totalSampled = 0;

    for (int y = startY; y < startY + sampleH; y++) {
      for (int x = startX; x < startX + sampleW; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        final h = _hue(r, g, b);
        final s = _saturation(r, g, b);
        final v = _value(r, g, b);

        final isGreen = h >= DartboardConstants.greenHueMin &&
            h <= DartboardConstants.greenHueMax &&
            s >= DartboardConstants.greenSatMin &&
            v >= DartboardConstants.greenValMin &&
            v <= DartboardConstants.greenValMax;

        final isRed = (h <= DartboardConstants.redHueMax ||
                h >= DartboardConstants.redHueMin) &&
            s >= DartboardConstants.redSatMin &&
            v >= DartboardConstants.redValMin &&
            v <= DartboardConstants.redValMax;

        if (isGreen || isRed) {
          mask[y][x] = true;
          coloredPixels++;
        }
        totalSampled++;
      }
    }

    final colorRatio = coloredPixels / totalSampled;
    if (colorRatio < DartboardConstants.minBoardColorRatio) return null;

    final blobs = _findBlobsFromMask(mask, width, height);
    if (blobs.isEmpty) return null;

    blobs.sort((a, b) => b.area.compareTo(a.area));
    final boardBlob = blobs.first;

    final centerX = boardBlob.sumX / boardBlob.area;
    final centerY = boardBlob.sumY / boardBlob.area;
    final radius = _radiusFromBlob(boardBlob, centerX, centerY, width, height);

    if (radius < DartboardConstants.minBoardRadiusPx) return null;

    return BoardCircle(
      centerX: centerX,
      centerY: centerY,
      radius: radius,
      tier: BoardDetectionTier.colorBased,
    );
  }

  static BoardCircle? _detectByBrightness(img.Image image) {
    final width = image.width;
    final height = image.height;

    final grayscale = _toGrayscale(image);
    final brightMask = List.generate(
      height,
      (y) => List.generate(
        width,
        (x) => grayscale[y][x] > DartboardConstants.boardBrightnessThreshold,
      ),
    );

    final blobs = _findBlobsFromMask(brightMask, width, height);
    if (blobs.isEmpty) return null;

    blobs.sort((a, b) => b.area.compareTo(a.area));
    final boardBlob = blobs.first;

    final minArea = (width * height * DartboardConstants.minBoardAreaRatio).toInt();
    if (boardBlob.area < minArea) return null;

    final centerX = boardBlob.sumX / boardBlob.area;
    final centerY = boardBlob.sumY / boardBlob.area;
    final radius = _refineRadius(grayscale, width, height, centerX, centerY);

    if (radius < DartboardConstants.minBoardRadiusPx) return null;

    return BoardCircle(
      centerX: centerX,
      centerY: centerY,
      radius: radius,
      tier: BoardDetectionTier.brightnessBased,
    );
  }

  static List<List<int>> _toGrayscale(img.Image image) {
    final w = image.width;
    final h = image.height;
    final gray = List.generate(h, (_) => List.filled(w, 0));

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final pixel = image.getPixel(x, y);
        gray[y][x] = ((pixel.r.toInt() * 0.299 +
                pixel.g.toInt() * 0.587 +
                pixel.b.toInt() * 0.114))
            .toInt();
      }
    }
    return gray;
  }

  static int _hue(int r, int g, int b) {
    final rf = r / 255;
    final gf = g / 255;
    final bf = b / 255;

    final maxVal = [rf, gf, bf].reduce(max);
    final minVal = [rf, gf, bf].reduce(min);
    final delta = maxVal - minVal;

    if (delta == 0) return 0;

    double hue;
    if (maxVal == rf) {
      hue = ((gf - bf) / delta) % 6;
    } else if (maxVal == gf) {
      hue = (bf - rf) / delta + 2;
    } else {
      hue = (rf - gf) / delta + 4;
    }

    hue *= 60;
    if (hue < 0) hue += 360;
    return hue.toInt();
  }

  static int _saturation(int r, int g, int b) {
    final maxVal = [r, g, b].reduce(max);
    final minVal = [r, g, b].reduce(min);
    if (maxVal == 0) return 0;
    return ((maxVal - minVal) / maxVal * 100).toInt();
  }

  static int _value(int r, int g, int b) {
    return (max(r, max(g, b)) / 255 * 100).toInt();
  }

  static double _radiusFromBlob(
      _BlobData blob, double centerX, double centerY, int width, int height) {
    final halfW = blob.maxX - blob.minX + 1;
    final halfH = blob.maxY - blob.minY + 1;
    return max(halfW, halfH) / 2;
  }

  static double _refineRadius(
    List<List<int>> gray,
    int width,
    int height,
    double centerX,
    double centerY,
  ) {
    final maxPossibleRadius =
        min(min(centerX, width - centerX), min(centerY, height - centerY))
            .toInt();

    final radii = <double>[];

    for (int angleDeg = 0; angleDeg < 360; angleDeg += 10) {
      final angleRad = angleDeg * pi / 180;
      final dx = cos(angleRad);
      final dy = sin(angleRad);

      int prevBrightness =
          _sampleBrightness(gray, width, height, centerX.toInt(), centerY.toInt());

      for (int r = 10; r < maxPossibleRadius; r += 3) {
        final px = (centerX + dx * r).toInt();
        final py = (centerY + dy * r).toInt();

        if (px < 0 || px >= width || py < 0 || py >= height) break;

        final brightness =
            _sampleBrightness(gray, width, height, px, py);

        if (prevBrightness - brightness >
            DartboardConstants.boardEdgeDropThreshold) {
          radii.add(r.toDouble());
          break;
        }
        prevBrightness = brightness;
      }
    }

    if (radii.isEmpty) {
      return max(maxPossibleRadius * 0.5, 50.0);
    }

    radii.sort();
    return radii[radii.length ~/ 2];
  }

  static int _sampleBrightness(
      List<List<int>> gray, int width, int height, int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return 0;
    return gray[y][x];
  }

  static List<_BlobData> _findBlobsFromMask(
      List<List<bool>> mask, int width, int height) {
    final visited = List.generate(height, (_) => List.filled(width, false));
    final blobs = <_BlobData>[];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (visited[y][x] || !mask[y][x]) continue;

        double sumX = 0;
        double sumY = 0;
        int area = 0;
        int minX = x, maxX = x, minY = y, maxY = y;

        final queue = <Point<int>>[Point(x, y)];
        visited[y][x] = true;

        while (queue.isNotEmpty) {
          final p = queue.removeLast();
          sumX += p.x;
          sumY += p.y;
          area++;

          if (p.x < minX) minX = p.x;
          if (p.x > maxX) maxX = p.x;
          if (p.y < minY) minY = p.y;
          if (p.y > maxY) maxY = p.y;

          for (final (dx, dy) in [
            (-1, 0),
            (1, 0),
            (0, -1),
            (0, 1),
          ]) {
            final nx = p.x + dx;
            final ny = p.y + dy;
            if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
            if (visited[ny][nx] || !mask[ny][nx]) continue;
            visited[ny][nx] = true;
            queue.add(Point(nx, ny));
          }
        }

        blobs.add(_BlobData(
          sumX: sumX,
          sumY: sumY,
          area: area,
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
        ));
      }
    }

    return blobs;
  }
}

class _BlobData {
  final double sumX;
  final double sumY;
  final int area;
  final int minX, maxX, minY, maxY;

  const _BlobData({
    required this.sumX,
    required this.sumY,
    required this.area,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });
}
