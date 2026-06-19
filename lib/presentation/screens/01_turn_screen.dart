import 'package:flutter/material.dart';
import '../../data/state/match_state_manager.dart';
import '../../data/models/match_state.dart';
import '../../main.dart';

class TurnScreen extends StatelessWidget {
  final MatchStateManager stateManager;
  final bool isCapturing;
  final VoidCallback onSnapShot;
  final VoidCallback onManualScore;
  final VoidCallback onEndMatch;

  const TurnScreen({
    super.key,
    required this.stateManager,
    required this.isCapturing,
    required this.onSnapShot,
    required this.onManualScore,
    required this.onEndMatch,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => _showEndMatchDialog(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          '${stateManager.value.gameType}',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: stateManager,
        builder: (context, state, child) {
          final currentState = state;
          if (currentState.isCompleted) {
            return _buildWinnerScreen(context, currentState);
          }
          return _buildGameView(context, currentState);
        },
      ),
    );
  }

  Widget _buildGameView(BuildContext context, DartMatchState state) {
    final activePlayer = state.activePlayer;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
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
          SizedBox(height: MediaQuery.of(context).size.height * 0.06),
          if (stateManager.canUndo)
            GestureDetector(
              onTap: () {
                stateManager.undoLastTurn();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Last turn undone'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.only(bottom: 12),
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
          GestureDetector(
            onTap: isCapturing ? null : onSnapShot,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCapturing ? Colors.grey[700] : kNeonOrange,
                boxShadow: isCapturing
                    ? []
                    : [
                        BoxShadow(
                          color: kNeonOrangeGlow.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
              ),
              child: isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: isCapturing ? null : onManualScore,
            child: const Text(
              'or type score',
              style: TextStyle(color: Colors.white38, fontSize: 14),
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
                onPressed: () => stateManager.resetMatch(),
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
                onPressed: onEndMatch,
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
              onEndMatch();
            },
            child: const Text('End Match', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
