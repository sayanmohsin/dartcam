import 'dart:math';
import 'package:image/image.dart' as img;
import '../constants/dartboard_constants.dart';

class BoardCircle {
  final double centerX;
  final double centerY;
  final double radius;

  const BoardCircle({
    required this.centerX,
    required this.centerY,
    required this.radius,
  });

  bool contains(double x, double y) {
    final dx = x - centerX;
    final dy = y - centerY;
    return dx * dx + dy * dy <= radius * radius;
  }
}

class BoardDetector {
  BoardDetector._();

  static BoardCircle? detectBoard(img.Image image) {
    final width = image.width;
    final height = image.height;

    final grayscale = _toGrayscale(image);

    final brightMask = _threshold(
      grayscale,
      width,
      height,
      DartboardConstants.boardBrightnessThreshold,
    );

    final blobs = _findBlobs(brightMask, width, height);
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

  static List<List<bool>> _threshold(
      List<List<int>> gray, int width, int height, int threshold) {
    return List.generate(
      height,
      (y) => List.generate(width, (x) => gray[y][x] > threshold),
    );
  }

  static List<_BlobData> _findBlobs(List<List<bool>> mask, int width, int height) {
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
            (-1, 0), (1, 0), (0, -1), (0, 1),
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

      int prevBrightness = _sampleBrightness(gray, width, height,
          centerX.toInt(), centerY.toInt());

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
      final blobRadius =
          max(maxPossibleRadius * 0.5, 50.0);
      return blobRadius;
    }

    radii.sort();
    final medianIndex = radii.length ~/ 2;
    return radii[medianIndex];
  }

  static int _sampleBrightness(
      List<List<int>> gray, int width, int height, int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return 0;
    return gray[y][x];
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
