import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../widgets/score_badge.dart' hide kNeonOrange, kNeonOrangeGlow;
import '../widgets/manual_picker_grid.dart' hide kNeonOrange, kNeonOrangeGlow;
import '../../core/vision/cv_engine.dart';
import '../../core/vision/scoring_geometry.dart';
import '../../data/state/match_state_manager.dart';
import '../../main.dart';

class _DetectionInput {
  final Uint8List shotBytes;
  final Uint8List? emptyBytes;
  final String emptyBoardPath;
  final String shotPath;

  const _DetectionInput({
    required this.shotBytes,
    this.emptyBytes,
    required this.emptyBoardPath,
    required this.shotPath,
  });
}

List<DetectedPoint> _processDartDetection(_DetectionInput input) {
  if (!kIsWeb) {
    return CVEngine.extractDartCentroids(
        input.emptyBoardPath, input.shotPath);
  }

  final shotImage = img.decodeImage(input.shotBytes);
  if (shotImage == null) return [];

  img.Image? emptyImage;
  if (input.emptyBytes != null) {
    emptyImage = img.decodeImage(input.emptyBytes!);
  }
  if (emptyImage == null) return [];

  return _processImagesPure(emptyImage, shotImage);
}

List<DetectedPoint> _processImagesPure(img.Image emptyImg, img.Image shotImg) {
  final width =
      emptyImg.width < shotImg.width ? emptyImg.width : shotImg.width;
  final height =
      emptyImg.height < shotImg.height ? emptyImg.height : shotImg.height;

  final diffPixels = <int, int>{};

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final emptyPixel = emptyImg.getPixel(x, y);
      final shotPixel = shotImg.getPixel(x, y);

      final dr = (shotPixel.r.toInt() - emptyPixel.r.toInt()).abs();
      final dg = (shotPixel.g.toInt() - emptyPixel.g.toInt()).abs();
      final db = (shotPixel.b.toInt() - emptyPixel.b.toInt()).abs();
      final gray = ((dr + dg + db) / 3).toInt();

      if (gray > 80) {
        diffPixels[y * width + x] = gray;
      }
    }
  }

  if (diffPixels.isEmpty) return [];

  final blobs = _findBlobsPure(diffPixels, width, height);
  blobs.sort((a, b) => b['area']!.compareTo(a['area']!));

  return blobs.take(3).map((blob) {
    return DetectedPoint(
      x: blob['cx']!,
      y: blob['cy']!,
      area: blob['area']!.toDouble(),
    );
  }).toList();
}

List<Map<String, double>> _findBlobsPure(
    Map<int, int> pixels, int width, int height) {
  final visited = <int>{};
  final blobs = <Map<String, double>>[];

  for (final entry in pixels.entries) {
    if (visited.contains(entry.key)) continue;

    final queue = [entry.key];
    visited.add(entry.key);

    double sumX = 0, sumY = 0;
    int area = 0;

    while (queue.isNotEmpty) {
      final idx = queue.removeLast();
      final x = idx % width;
      final y = idx ~/ width;
      sumX += x;
      sumY += y;
      area++;

      for (final offset in [-1, 1, -width, width]) {
        final neighbor = idx + offset;
        if (neighbor < 0 || neighbor >= width * height) continue;
        if (visited.contains(neighbor)) continue;
        if (!pixels.containsKey(neighbor)) continue;

        final ny = neighbor ~/ width;
        if ((offset == -1 || offset == 1) && ny != y) continue;

        visited.add(neighbor);
        queue.add(neighbor);
      }
    }

    if (area >= 200) {
      blobs.add({
        'cx': sumX / area,
        'cy': sumY / area,
        'area': area.toDouble(),
      });
    }
  }

  return blobs;
}

class DetectionScreen extends StatefulWidget {
  final MatchStateManager stateManager;
  final String emptyBoardPath;
  final String shotPath;
  final VoidCallback onRetake;
  final VoidCallback onConfirmed;

  const DetectionScreen({
    super.key,
    required this.stateManager,
    required this.emptyBoardPath,
    required this.shotPath,
    required this.onRetake,
    required this.onConfirmed,
  });

  static final Map<String, Uint8List> _webImageCache = {};
  static Uint8List? getWebImage(String key) => _webImageCache[key];
  static bool hasWebImage(String key) => _webImageCache.containsKey(key);
  static void setWebImage(String key, Uint8List bytes) =>
      _webImageCache[key] = bytes;
  static void clearWebImage(String key) => _webImageCache.remove(key);

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with SingleTickerProviderStateMixin {
  List<ScoredDart> _scoredDarts = [];
  bool _isProcessing = true;
  String? _error;
  Uint8List? _shotBytes;
  bool _isConfirmed = false;
  bool _noDartsDetected = false;

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  int _loadingStep = 0;

  static const _loadingSteps = [
    'Loading image...',
    'Analyzing...',
    'Scoring...',
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _loadAndProcess();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _setStep(int step) {
    if (!mounted) return;
    setState(() => _loadingStep = step);
    _progressController.animateTo((step + 1) / _loadingSteps.length);
  }

  Future<void> _waitForMinDuration(DateTime start, int minMs) async {
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    if (elapsed < minMs) {
      await Future.delayed(Duration(milliseconds: minMs - elapsed));
    }
  }

  Future<void> _loadAndProcess() async {
    try {
      _setStep(0);
      final loadStart = DateTime.now();

      Uint8List? shotBytes;
      Uint8List? emptyBytes;

      if (kIsWeb) {
        shotBytes = DetectionScreen.getWebImage(widget.shotPath);
        emptyBytes = DetectionScreen.getWebImage(widget.emptyBoardPath);
      } else {
        final file = File(widget.shotPath);
        if (!await file.exists()) {
          setState(() {
            _error = 'Shot image not found';
            _isProcessing = false;
          });
          return;
        }
        shotBytes = await file.readAsBytes();
        final emptyFile = File(widget.emptyBoardPath);
        if (await emptyFile.exists()) {
          emptyBytes = await emptyFile.readAsBytes();
        }
      }

      if (shotBytes == null) {
        setState(() {
          _error = 'Shot image not found';
          _isProcessing = false;
        });
        return;
      }

      final shotImage = img.decodeImage(shotBytes);
      if (shotImage == null) {
        setState(() {
          _error = 'Failed to decode image';
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _shotBytes = shotBytes;
      });
      await _waitForMinDuration(loadStart, 600);

      _setStep(1);
      final analyzeStart = DateTime.now();

      final input = _DetectionInput(
        shotBytes: shotBytes,
        emptyBytes: emptyBytes,
        emptyBoardPath: widget.emptyBoardPath,
        shotPath: widget.shotPath,
      );

      final points = await compute(_processDartDetection, input);
      await _waitForMinDuration(analyzeStart, 500);

      if (points.isEmpty) {
        setState(() {
          _noDartsDetected = true;
          _isProcessing = false;
        });
        return;
      }

      _setStep(2);
      final scoreStart = DateTime.now();

      final scoredDarts = ScoringGeometry.scoreAllDarts(
        points,
        shotImage.width.toDouble(),
        shotImage.height.toDouble(),
      );

      await _waitForMinDuration(scoreStart, 400);

      if (mounted) {
        setState(() {
          _scoredDarts = scoredDarts;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Processing failed: $e';
          _isProcessing = false;
        });
      }
    }
  }

  int get turnTotal => _scoredDarts.fold(0, (sum, d) => sum + d.totalScore);

  Future<void> _editDart(int index) async {
    final dart = _scoredDarts[index];
    final result = await showModalBottomSheet<ManualPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCardBg,
      builder: (context) => ManualPickerGrid(
        initialScore: dart.score,
        initialLabel: dart.label,
      ),
    );

    if (result != null) {
      setState(() {
        _scoredDarts[index] = ScoredDart(
          score: result.score,
          multiplier: result.multiplier,
          label: result.label,
        );
      });
    }
  }

  void _confirmScore() {
    if (_isConfirmed) return;
    _isConfirmed = true;

    final scores = _scoredDarts.map((d) => d.totalScore).toList();
    while (scores.length < 3) {
      scores.add(0);
    }

    final bustResult = widget.stateManager.recordTurn(
      scores.sublist(0, 3),
      darts: _scoredDarts,
    );

    if (bustResult != BustResult.none && mounted) {
      String message;
      switch (bustResult) {
        case BustResult.overBust:
          message = 'Bust! Score went below 0';
          break;
        case BustResult.oneBust:
          message = 'Bust! Cannot finish on 1';
          break;
        case BustResult.notDouble:
          message = 'Bust! Must finish on a double';
          break;
        default:
          message = 'Bust!';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    widget.onConfirmed();
  }

  void _retake() {
    if (!kIsWeb) {
      final shotFile = File(widget.shotPath);
      if (shotFile.existsSync()) {
        shotFile.deleteSync();
      }
    } else {
      DetectionScreen.clearWebImage(widget.shotPath);
    }
    widget.onRetake();
  }

  void _goToManualEntry() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualEntryScreen(
          stateManager: widget.stateManager,
          onConfirmed: () {
            Navigator.of(context).pop();
            widget.onConfirmed();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _retake,
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          _isProcessing
              ? 'Analyzing...'
              : _noDartsDetected
                  ? 'No Darts Found'
                  : 'Review Darts',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isProcessing
                      ? _buildLoadingView()
                      : _error != null
                          ? _buildErrorView()
                          : _noDartsDetected
                              ? _buildNoDartsView()
                              : _buildImageView(),
                ),
              ),
              const SizedBox(height: 16),
              if (!_noDartsDetected && _error == null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    if (index < _scoredDarts.length) {
                      final dart = _scoredDarts[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: ScoreBadge(
                          score: dart.totalScore,
                          label: dart.label,
                          onTap: () => _editDart(index),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: _isProcessing ? null : () => _addDart(index),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: kInputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kNeonOrange,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add,
                                  color: Colors.grey[500], size: 24),
                              Text(
                                'Dart ${index + 1}',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  'Turn Total: $turnTotal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const Spacer(),
              if (_noDartsDetected || _error != null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _retake,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _goToManualEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kNeonOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Enter Manually'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _retake,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Retake'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _scoredDarts.isNotEmpty && !_isProcessing
                            ? _confirmScore
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kNeonOrange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('ADD SCORE'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      color: kCardBg,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: kNeonOrange,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _loadingSteps[_loadingStep],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                _loadingSteps.length,
                (i) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= _loadingStep ? kNeonOrange : Colors.white24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _progressAnimation.value,
                      color: kNeonOrange,
                      backgroundColor: Colors.white12,
                      minHeight: 3,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: kCardBg,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, color: Colors.white38, size: 48),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoDartsView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_shotBytes != null)
          kIsWeb
              ? Image.memory(_shotBytes!, fit: BoxFit.contain)
              : Image.file(File(widget.shotPath), fit: BoxFit.contain)
        else
          Container(color: kInputBg),
        Container(
          color: Colors.black54,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.gps_off, color: Colors.white54, size: 48),
                SizedBox(height: 16),
                Text(
                  'No darts detected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Make sure darts are clearly visible\non the board',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageView() {
    if (kIsWeb && _shotBytes != null) {
      return Image.memory(
        _shotBytes!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: kInputBg,
            child: const Center(
              child:
                  Icon(Icons.broken_image, color: Colors.grey, size: 64),
            ),
          );
        },
      );
    } else if (!kIsWeb && _shotBytes != null) {
      return Image.file(
        File(widget.shotPath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: kInputBg,
            child: const Center(
              child:
                  Icon(Icons.broken_image, color: Colors.grey, size: 64),
            ),
          );
        },
      );
    }
    return Container(
      color: kInputBg,
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey, size: 64),
      ),
    );
  }

  Future<void> _addDart(int index) async {
    final result = await showModalBottomSheet<ManualPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCardBg,
      builder: (context) => const ManualPickerGrid(
        initialScore: 20,
        initialLabel: '20',
      ),
    );

    if (result != null) {
      setState(() {
        while (_scoredDarts.length <= index) {
          _scoredDarts
              .add(const ScoredDart(score: 0, multiplier: 1, label: '0'));
        }
        _scoredDarts[index] = ScoredDart(
          score: result.score,
          multiplier: result.multiplier,
          label: result.label,
        );
      });
    }
  }
}
