import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import '../../core/constants/dartboard_constants.dart';

class DetectedPoint {
  final double x;
  final double y;
  final double area;

  const DetectedPoint({required this.x, required this.y, required this.area});
}

abstract class CVEngine {
  static List<DetectedPoint> extractDartCentroids(
      String emptyPath, String shotPath) {
    return PureDartCVEngine.extractDartCentroids(emptyPath, shotPath);
  }
}

class PureDartCVEngine {
  static List<DetectedPoint> extractDartCentroids(
      String emptyPath, String shotPath) {
    final emptyBytes = File(emptyPath).readAsBytesSync();
    final shotBytes = File(shotPath).readAsBytesSync();

    final emptyImage = img.decodeImage(emptyBytes);
    final shotImage = img.decodeImage(shotBytes);

    if (emptyImage == null || shotImage == null) {
      return [];
    }

    final width = min(emptyImage.width, shotImage.width);
    final height = min(emptyImage.height, shotImage.height);

    final diffImage = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final emptyPixel = emptyImage.getPixel(x, y);
        final shotPixel = shotImage.getPixel(x, y);

        final dr = (shotPixel.r.toInt() - emptyPixel.r.toInt()).abs();
        final dg = (shotPixel.g.toInt() - emptyPixel.g.toInt()).abs();
        final db = (shotPixel.b.toInt() - emptyPixel.b.toInt()).abs();

        final gray = ((dr + dg + db) / 3).toInt();

        if (gray > DartboardConstants.imageDiffThreshold) {
          diffImage.setPixelRgba(x, y, 255, 255, 255, 255);
        } else {
          diffImage.setPixelRgba(x, y, 0, 0, 0, 255);
        }
      }
    }

    final blobs = _findBlobs(diffImage);

    final sortedBlobs = List<Blob>.from(blobs)
      ..sort((a, b) => b.area.compareTo(a.area));

    final topBlobs = sortedBlobs
        .take(DartboardConstants.maxDetectedBlobs)
        .toList();

    return topBlobs.map((blob) {
      final centroid = blob.centroid;
      return DetectedPoint(
        x: centroid.x,
        y: centroid.y,
        area: blob.area.toDouble(),
      );
    }).toList();
  }

  static List<Blob> _findBlobs(img.Image binaryImage) {
    final visited = List.generate(
      binaryImage.height,
      (y) => List.generate(binaryImage.width, (x) => false),
    );

    final blobs = <Blob>[];

    for (int y = 0; y < binaryImage.height; y++) {
      for (int x = 0; x < binaryImage.width; x++) {
        if (visited[y][x]) continue;

        final pixel = binaryImage.getPixel(x, y);
        if (pixel.r.toInt() == 0 && pixel.g.toInt() == 0 && pixel.b.toInt() == 0) {
          continue;
        }

        final blob = _floodFill(binaryImage, visited, x, y);
        if (blob.area > 10) {
          blobs.add(blob);
        }
      }
    }

    return blobs;
  }

  static Blob _floodFill(
      img.Image image, List<List<bool>> visited, int startX, int startY) {
    final queue = <Point<int>>[Point(startX, startY)];
    visited[startY][startX] = true;

    double sumX = 0;
    double sumY = 0;
    int area = 0;

    while (queue.isNotEmpty) {
      final point = queue.removeLast();
      sumX += point.x;
      sumY += point.y;
      area++;

      for (final neighbor in _getNeighbors(point.x, point.y, image.width, image.height)) {
        if (visited[neighbor.y][neighbor.x]) continue;

        final pixel = image.getPixel(neighbor.x, neighbor.y);
        if (pixel.r.toInt() > 0 || pixel.g.toInt() > 0 || pixel.b.toInt() > 0) {
          visited[neighbor.y][neighbor.x] = true;
          queue.add(neighbor);
        }
      }
    }

    return Blob(
      centroid: Offset(sumX / area, sumY / area),
      area: area,
    );
  }

  static List<Point<int>> _getNeighbors(int x, int y, int width, int height) {
    final neighbors = <Point<int>>[];
    const offsets = [
      (-1, 0), (1, 0), (0, -1), (0, 1),
    ];

    for (final (dx, dy) in offsets) {
      final nx = x + dx;
      final ny = y + dy;
      if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
        neighbors.add(Point(nx, ny));
      }
    }

    return neighbors;
  }
}

class Blob {
  final Offset centroid;
  final int area;

  const Blob({required this.centroid, required this.area});
}

class Offset {
  final double x;
  final double y;

  const Offset(this.x, this.y);
}
