import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui' as ui show PlatformDispatcher;
import 'package:path_provider/path_provider.dart';
import 'presentation/screens/00_splash_screen.dart';
import 'presentation/screens/01_turn_screen.dart';
import 'presentation/screens/03_detection_screen.dart';
import 'presentation/screens/04_about_screen.dart';
import 'presentation/screens/05_cloud_settings_screen.dart';
import 'presentation/screens/camera_screen.dart';
import 'presentation/widgets/manual_picker_grid.dart';
import 'presentation/widgets/dartboard_picker.dart';
import 'core/vision/dartboard_scorer.dart';
import 'data/state/match_state_manager.dart';
import 'services/thingd_service.dart';
import 'services/cloud_auth_service.dart';
import 'data/models/cloud_credentials.dart';

const kNeonOrange = Color(0xFFFF6D00);
const kNeonOrangeGlow = Color(0xFFFF9100);
const kDarkBg = Color(0xFF121212);
const kCardBg = Color(0xFF1E1E1E);
const kInputBg = Color(0xFF2A2A2A);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    debugPrint('Unhandled Flutter error: ${details.exception}');
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled platform error: $error');
    return true;
  };
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
      home: const AppLoader(),
    );
  }
}

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});
  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with WidgetsBindingObserver {
  ThingdService? _thingd;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _thingd?.walCheckpoint();
    }
  }

  Future<void> _init() async {
    try {
      final thingd = await ThingdService.open();
      if (mounted) {
        setState(() {
          _thingd = thingd;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF111215),
        body: Center(child: CircularProgressIndicator(color: kNeonOrange)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF111215),
        body: Center(
          child: Text('Failed to initialize: $_error',
              style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    return SplashScreen(thingd: _thingd!);
  }
}

// ---------- SETUP SCREEN ----------

class SetupScreen extends StatefulWidget {
  final ThingdService thingd;
  const SetupScreen({super.key, required this.thingd});

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

  Future<void> _startGame() async {
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

    final stateManager = await MatchStateManager.create(
      thingd: widget.thingd,
      playerNames: names,
      gameType: _selectedGameType,
    );

    if (!mounted) return;
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
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CloudSettingsScreen(thingd: widget.thingd),
                        ),
                      );
                    },
                    child: const Icon(Icons.cloud_outlined, color: Colors.white24, size: 18),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                    child: const Icon(Icons.info_outline, color: Colors.white24, size: 20),
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

// ---------- GAME SCREEN ----------

class GameScreen extends StatefulWidget {
  final MatchStateManager stateManager;
  const GameScreen({super.key, required this.stateManager});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _isCapturing = false;

  Future<void> _onThrowDarts() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final String? imagePath = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );

      if (imagePath == null || !mounted) {
        setState(() => _isCapturing = false);
        return;
      }

      String emptyBoardPath;
      String shotPath;

      final directory = await getApplicationDocumentsDirectory();
      emptyBoardPath = '${directory.path}/empty_board_base.png';
      shotPath = '${directory.path}/active_turn_shot.png';

      final emptyFile = File(emptyBoardPath);
      if (!await emptyFile.exists()) {
        await File(imagePath).copy(emptyBoardPath);
      }
      await File(imagePath).copy(shotPath);

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

  Future<void> _onEndMatch() async {
    await widget.stateManager.endMatch();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SetupScreen(thingd: widget.stateManager.thingd)),
      );
    }
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

class _ManualEntryScreenState extends State<ManualEntryScreen>
    with SingleTickerProviderStateMixin {
  final List<ScoredDart?> _darts = [null, null, null];
  int _currentDart = 0;
  bool _isConfirmed = false;

  late AnimationController _slotController;
  late Animation<double> _slotAnimation;

  int get _turnTotal => _darts.fold(0, (sum, d) => sum + (d?.totalScore ?? 0));
  int get _dartCount => _darts.where((d) => d != null && d.totalScore > 0).length;
  bool get _allDartsFilled => _darts.every((d) => d != null);

  @override
  void initState() {
    super.initState();
    _slotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _slotAnimation = CurvedAnimation(
      parent: _slotController,
      curve: Curves.easeOut,
    );
    _slotController.forward();
  }

  @override
  void dispose() {
    _slotController.dispose();
    super.dispose();
  }

  void _handleScore(ManualPickerResult? result) {
    if (_currentDart >= 3) return;

    if (result == null) {
      setState(() {
        _darts[_currentDart] = const ScoredDart(score: 0, multiplier: 1, label: '0');
        _currentDart++;
      });
    } else {
      setState(() {
        _darts[_currentDart] = ScoredDart(
          score: result.score,
          multiplier: result.multiplier,
          label: result.label,
        );
        _currentDart++;
      });
    }
    _slotController.forward(from: 0);
  }

  Future<void> _submitTurn() async {
    if (_isConfirmed) return;
    _isConfirmed = true;

    final scores = _darts.map((d) => d?.totalScore ?? 0).toList();

    final bustResult = await widget.stateManager.recordTurn(
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
    final allFilled = _allDartsFilled;
    final boardSize = MediaQuery.of(context).size.width * 0.92;

    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Row(
          children: [
            Text(
              widget.stateManager.value.activePlayer.name.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Spacer(),
            Text(
              _currentDart < 3 ? 'Dart ${_currentDart + 1}/3' : 'Complete',
              style: const TextStyle(color: kNeonOrange, fontSize: 14),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Compact score indicator row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.stateManager.value.activePlayer.currentScore} remaining',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                Text(
                  'Turn: $_turnTotal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Dart slots (compact row)
          AnimatedBuilder(
            animation: _slotAnimation,
            builder: (context, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final dart = _darts[index];
                    final isActive = index == _currentDart && index < 3;
                    final isFilled = dart != null;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 52 : 44,
                        height: isActive ? 52 : 44,
                        decoration: BoxDecoration(
                          color: isFilled
                              ? kNeonOrange
                              : (isActive ? kInputBg : const Color(0xFF1A1A1A)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive
                                ? kNeonOrangeGlow
                                : (isFilled
                                    ? kNeonOrange.withOpacity(0.5)
                                    : Colors.grey[800]!),
                            width: isActive ? 2.5 : 1.5,
                          ),
                        ),
                        child: isFilled
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    dart!.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${dart.totalScore}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive ? Colors.white38 : Colors.grey[700],
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),

          const SizedBox(height: 4),

          // Dartboard fills remaining space (fixed size for consistency)
          Expanded(
            child: DartboardPicker(
              onScore: _handleScore,
              fixedSize: boardSize,
            ),
          ),

          // Submit button — only after all 3 darts are filled
          if (allFilled)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitTurn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kNeonOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'ADD SCORE — $_turnTotal',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                _currentDart < 3
                    ? 'Tap the board to score Dart ${_currentDart + 1}'
                    : 'Set all 3 darts to continue',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
