import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'presentation/screens/00_splash_screen.dart';
import 'presentation/screens/01_turn_screen.dart';
import 'presentation/screens/03_detection_screen.dart';
import 'presentation/screens/04_about_screen.dart';
import 'presentation/widgets/manual_picker_grid.dart';
import 'core/vision/scoring_geometry.dart';
import 'data/state/match_state_manager.dart';

const kNeonOrange = Color(0xFFFF6D00);
const kNeonOrangeGlow = Color(0xFFFF9100);
const kDarkBg = Color(0xFF121212);
const kCardBg = Color(0xFF1E1E1E);
const kInputBg = Color(0xFF2A2A2A);

void main() {
  runApp(const DartScorerApp());
}

class DartScorerApp extends StatelessWidget {
  const DartScorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DartCam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: kNeonOrange,
          surface: kDarkBg,
        ),
        scaffoldBackgroundColor: kDarkBg,
      ),
      home: const SplashScreen(),
    );
  }
}

// ---------- SETUP SCREEN ----------

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final List<TextEditingController> _controllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _selectedGameType = 501;

  static const _gameTypeOptions = [301, 501, 701, 1001];

  void _addPlayer() {
    if (_controllers.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 8 players')),
      );
      return;
    }
    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  void _removePlayer(int index) {
    if (_controllers.length <= 2) return;
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
  }

  void _startGame() {
    final names = _controllers
        .map((c) => c.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    if (names.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter at least 2 player names'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final uniqueNames = names.toSet();
    if (uniqueNames.length != names.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Player names must be unique'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final stateManager = MatchStateManager(
      playerNames: names,
      gameType: _selectedGameType,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(stateManager: stateManager),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Column(
                    children: [
                      Text(
                        'DARTCAM',
                        style: TextStyle(
                          color: kNeonOrange,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Snap. Score. Win.',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Text(
                'Game Type',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: _gameTypeOptions.map((type) {
                  final isSelected = type == _selectedGameType;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGameType = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? kNeonOrange : kInputBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? kNeonOrangeGlow : Colors.grey[700]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$type',
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.rule, color: kNeonOrange, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'RULES',
                          style: TextStyle(
                            color: kNeonOrange,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ruleItem('Start at $_selectedGameType points'),
                    _ruleItem('Each player throws up to 3 darts per turn'),
                    _ruleItem('Must finish on a double or bullseye'),
                    _ruleItem('Going below 0 is a bust'),
                    _ruleItem('Finishing on 1 is a bust'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Players',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${_controllers.length} of 8',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _controllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: kNeonOrange,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _controllers[index],
                            style: const TextStyle(color: Colors.white),
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'Player ${index + 1} name',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              filled: true,
                              fillColor: kInputBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: kNeonOrange),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        if (_controllers.length > 2)
                          IconButton(
                            onPressed: () => _removePlayer(index),
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          ),
                      ],
                    ),
                  );
                },
              ),
              TextButton.icon(
                onPressed: _addPlayer,
                icon: const Icon(Icons.add, color: kNeonOrange),
                label: const Text('Add Player', style: TextStyle(color: kNeonOrange)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kNeonOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'START MATCH',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                    icon: const Icon(Icons.info_outline, color: Colors.white24, size: 20),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'v0.1.0 Beta',
                    style: TextStyle(color: Colors.white24, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('  ', style: TextStyle(color: kNeonOrange, fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- GAME SCREEN ----------

class GameScreen extends StatefulWidget {
  final MatchStateManager stateManager;
  const GameScreen({super.key, required this.stateManager});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isCapturing = false;

  Future<void> _onThrowDarts() async {
    if (_isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo == null) {
        if (mounted) setState(() => _isCapturing = false);
        return;
      }

      String emptyBoardPath;
      String shotPath;

      if (kIsWeb) {
        final bytes = await photo.readAsBytes();
        const emptyKey = 'empty_board_base.png';
        const shotKey = 'active_turn_shot.png';

        DetectionScreen.setWebImage(shotKey, bytes);
        if (!DetectionScreen.hasWebImage(emptyKey)) {
          DetectionScreen.setWebImage(emptyKey, bytes);
        }
        emptyBoardPath = emptyKey;
        shotPath = shotKey;
      } else {
        final directory = await getApplicationDocumentsDirectory();
        emptyBoardPath = '${directory.path}/empty_board_base.png';
        shotPath = '${directory.path}/active_turn_shot.png';

        final emptyFile = File(emptyBoardPath);
        if (!await emptyFile.exists()) {
          await File(photo.path).copy(emptyBoardPath);
        }
        await File(photo.path).copy(shotPath);
      }

      if (!mounted) return;
      setState(() => _isCapturing = false);

      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, _, _) => DetectionScreen(
            stateManager: widget.stateManager,
            emptyBoardPath: emptyBoardPath,
            shotPath: shotPath,
            onRetake: () => Navigator.of(context).pop(),
            onConfirmed: () => Navigator.of(context).pop(),
          ),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onManualScore() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualEntryScreen(
          stateManager: widget.stateManager,
          onConfirmed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _onEndMatch() {
    widget.stateManager.endMatch();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TurnScreen(
      stateManager: widget.stateManager,
      isCapturing: _isCapturing,
      onSnapShot: _onThrowDarts,
      onManualScore: _onManualScore,
      onEndMatch: _onEndMatch,
    );
  }
}

// ---------- MANUAL ENTRY SCREEN ----------

class ManualEntryScreen extends StatefulWidget {
  final MatchStateManager stateManager;
  final VoidCallback onConfirmed;

  const ManualEntryScreen({
    super.key,
    required this.stateManager,
    required this.onConfirmed,
  });

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final List<ScoredDart?> _darts = [null, null, null];
  bool _isConfirmed = false;

  int get _turnTotal => _darts.fold(0, (sum, d) => sum + (d?.totalScore ?? 0));
  int get _dartCount => _darts.where((d) => d != null && d.totalScore > 0).length;

  Future<void> _editDart(int index) async {
    final current = _darts[index];
    final result = await showModalBottomSheet<ManualPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCardBg,
      builder: (context) => ManualPickerGrid(
        initialScore: current?.score ?? 20,
        initialLabel: current?.label ?? '20',
      ),
    );

    if (result != null) {
      setState(() {
        _darts[index] = ScoredDart(
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

    final scores = _darts.map((d) => d?.totalScore ?? 0).toList();

    final bustResult = widget.stateManager.recordTurn(
      scores,
      darts: _darts.whereType<ScoredDart>().toList(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text('Enter Score', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              widget.stateManager.value.activePlayer.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.stateManager.value.activePlayer.currentScore} remaining',
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final dart = _darts[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => _editDart(index),
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: dart != null ? kNeonOrange : kInputBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: dart != null ? kNeonOrangeGlow : Colors.grey[700]!,
                          width: 2,
                        ),
                      ),
                      child: dart != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dart.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${dart.totalScore}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, color: Colors.grey[600], size: 28),
                                Text(
                                  'Dart ${index + 1}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Text(
              'Turn Total: $_turnTotal',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _dartCount > 0 ? _confirmScore : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNeonOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'ADD SCORE',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
