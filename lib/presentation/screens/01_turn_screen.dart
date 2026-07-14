import 'package:flutter/material.dart';
import '../../data/state/match_state_manager.dart';
import '../../data/models/match_state.dart';
import '../../core/vision/dartboard_scorer.dart';
import '../../main.dart';
import '../widgets/dartboard_picker.dart';
import '../widgets/manual_picker_grid.dart' hide kNeonOrange, kNeonOrangeGlow;

class TurnScreen extends StatefulWidget {
  final MatchStateManager stateManager;
  final bool isCapturing;
  final VoidCallback onSnapShot;
  final VoidCallback onEndMatch;

  const TurnScreen({
    super.key,
    required this.stateManager,
    required this.isCapturing,
    required this.onSnapShot,
    required this.onEndMatch,
  });

  @override
  State<TurnScreen> createState() => _TurnScreenState();
}

class _TurnScreenState extends State<TurnScreen> {
  bool _showDartboard = false;
  final List<ScoredDart?> _darts = [null, null, null];
  int _currentDart = 0;

  int get _turnTotal => _darts.fold(0, (sum, d) => sum + (d?.totalScore ?? 0));
  bool get _allDartsFilled => _darts.every((d) => d != null);

  void _openDartboard() {
    setState(() {
      _showDartboard = true;
      _darts[0] = null;
      _darts[1] = null;
      _darts[2] = null;
      _currentDart = 0;
    });
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
  }

  Future<void> _submitTurn() async {
    final scores = _darts.map((d) => d?.totalScore ?? 0).toList();
    final bustResult = await widget.stateManager.recordTurn(
      scores,
      darts: _darts.whereType<ScoredDart>().toList(),
      isAutoDetected: false,
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

    if (mounted) {
      setState(() {
        _showDartboard = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _showDartboard
              ? () => setState(() => _showDartboard = false)
              : () => _showEndMatchDialog(context),
          icon: Icon(
            _showDartboard ? Icons.close : Icons.arrow_back,
            color: Colors.white,
          ),
        ),
        title: Text(
          _showDartboard ? 'Enter Score' : '${widget.stateManager.value.gameType}',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        centerTitle: !_showDartboard,
        actions: _showDartboard
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Text(
                      _currentDart < 3 ? 'Dart ${_currentDart + 1}/3' : 'Done',
                      style: TextStyle(color: kNeonOrange, fontSize: 14),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: ValueListenableBuilder(
        key: ValueKey(_showDartboard),
        valueListenable: widget.stateManager,
        builder: (context, state, child) {
          if (state.isCompleted) {
            return _buildWinnerScreen(context, state);
          }
          if (_showDartboard) {
            return _buildDartboardView(state);
          }
          return _buildGameView(context, state);
        },
      ),
    );
  }

  Widget _buildDartboardView(DartMatchState state) {
    final allFilled = _allDartsFilled;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${state.activePlayer.currentScore} remaining',
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
        Padding(
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
                  width: isActive ? 48 : 40,
                  height: isActive ? 48 : 40,
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
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${dart.totalScore}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white38 : Colors.grey[700],
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.92,
              height: MediaQuery.of(context).size.width * 0.92,
              child: DartboardPicker(onScore: _handleScore),
            ),
          ),
        ),
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
            padding: const EdgeInsets.only(bottom: 24),
            child: TextButton(
              onPressed: () => _handleScore(null),
              child: const Text(
                'MISS',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGameView(BuildContext context, DartMatchState state) {
    final activePlayer = state.activePlayer;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _buildScoreboard(state),
          const SizedBox(height: 24),
          Text(
            activePlayer.name.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${activePlayer.currentScore}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 96,
              fontWeight: FontWeight.w300,
              fontFamily: 'monospace',
            ),
          ),
          if (state.history.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Last turn: ${state.history.last.totalTurnScore} pts',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).size.height * 0.04),
          if (widget.stateManager.canUndo)
            GestureDetector(
              onTap: () async {
                await widget.stateManager.undoLastTurn();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Last turn undone'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.undo, color: Colors.white38, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Undo last turn',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: widget.isCapturing ? null : _openDartboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: kNeonOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ENTER SCORE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: widget.isCapturing ? null : widget.onSnapShot,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, color: Colors.white38, size: 16),
                const SizedBox(width: 6),
                widget.isCapturing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white38,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'or capture with camera',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildScoreboard(DartMatchState state) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(state.players.length, (index) {
          final player = state.players[index];
          final isActive = index == state.activePlayerIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                if (isActive)
                  const Icon(Icons.play_arrow, color: kNeonOrange, size: 20)
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    player.name,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 16,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                Text(
                  '${player.currentScore}',
                  style: TextStyle(
                    color: isActive ? kNeonOrange : Colors.white70,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWinnerScreen(BuildContext context, DartMatchState state) {
    final winner = state.activePlayer;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, size: 120, color: Color(0xFFFFD700)),
            const SizedBox(height: 16),
            Text(
              '${winner.name.toUpperCase()} WINS!',
              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Final Score: ${winner.currentScore}',
              style: const TextStyle(color: Colors.white70, fontSize: 20),
            ),
            const SizedBox(height: 16),
            Text(
              '${state.history.length} turns played',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async => await widget.stateManager.resetMatch(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNeonOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'PLAY AGAIN',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: widget.onEndMatch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'NEW MATCH',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEndMatchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('End Match?', style: TextStyle(color: Colors.white)),
        content: const Text('Current match progress will be lost.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onEndMatch();
            },
            child: const Text('End Match', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
