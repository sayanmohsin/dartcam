import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:local_dart_scorer/data/models/match_state.dart';
import 'package:local_dart_scorer/data/models/player_profile.dart';
import 'package:local_dart_scorer/data/models/turn_mutation.dart';
import 'package:local_dart_scorer/services/thingd_service.dart';

/// Pre-migration benchmark: simulates shared_preferences approach.
///
/// Old code saved the ENTIRE DartMatchState (all turns included) as a
/// single JSON string in shared_preferences on every turn.
class OldSharedPreferencesApproach {
  String? _blob;

  /// Simulates the old save: serialize entire state to one JSON string.
  void saveMatchState(DartMatchState state) {
    _blob = jsonEncode(state.toJson());
  }

  /// Simulates the old load: deserialize entire state from JSON string.
  DartMatchState? loadMatchState() {
    if (_blob == null) return null;
    return DartMatchState.fromJson(jsonDecode(_blob!) as Map<String, dynamic>);
  }

  /// Simulates the old undo: load, pop last, re-save.
  DartMatchState undoLastTurn() {
    final state = loadMatchState()!;
    final history = List<TurnMutation>.from(state.history)..removeLast();

    final updatedPlayers = List<PlayerProfile>.from(state.players);
    final lastMutation = state.history.last;
    for (int i = 0; i < updatedPlayers.length; i++) {
      if (updatedPlayers[i].id == lastMutation.playerId) {
        updatedPlayers[i] = updatedPlayers[i]
            .copyWith(currentScore: lastMutation.scoreBeforeTurn);
        break;
      }
    }

    final undone = state.copyWith(
      players: updatedPlayers,
      history: history,
      status: MatchStatus.active,
      activePlayerIndex: state.players.indexWhere(
        (p) => p.id == lastMutation.playerId,
      ),
    );
    saveMatchState(undone);
    return undone;
  }

  /// JSON blob size in bytes.
  int get blobSize => utf8.encode(_blob ?? '').length;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('DartCam Persistence Benchmark', () {
    const uuid = Uuid();
    final playerIds = [uuid.v4(), uuid.v4()];
    final playerNames = ['Alice', 'Bob'];

    /// Generate a realistic TurnMutation.
    TurnMutation makeTurn(int turnIndex, String playerId, int scoreBefore) {
      // Random-ish scores: 1-60 per dart, 1-3 darts
      final dartCount = 1 + (turnIndex % 3);
      final scores = List.generate(
        dartCount,
        (i) => ((turnIndex * 7 + i * 13) % 60) + 1,
      );
      final total = scores.fold(0, (s, v) => s + v);
      return TurnMutation(
        playerId: playerId,
        detectedScores: scores,
        totalTurnScore: total,
        scoreBeforeTurn: scoreBefore,
      );
    }

    /// Build a match state with N turns already recorded.
    (DartMatchState, OldSharedPreferencesApproach) buildState(int turnCount) {
      var scoreA = 501;
      var scoreB = 501;
      final history = <TurnMutation>[];
      final players = [
        PlayerProfile(id: playerIds[0], name: playerNames[0], currentScore: scoreA),
        PlayerProfile(id: playerIds[1], name: playerNames[1], currentScore: scoreB),
      ];

      for (int i = 0; i < turnCount; i++) {
        final pid = i.isEven ? playerIds[0] : playerIds[1];
        final currentScore = i.isEven ? scoreA : scoreB;
        final turn = makeTurn(i, pid, currentScore);
        history.add(turn);
        final newScore = currentScore - turn.totalTurnScore;
        if (i.isEven) {
          scoreA = newScore.clamp(0, 501);
          players[0] = players[0].copyWith(currentScore: scoreA);
        } else {
          scoreB = newScore.clamp(0, 501);
          players[1] = players[1].copyWith(currentScore: scoreB);
        }
      }

      final state = DartMatchState(
        gameType: 501,
        activePlayerIndex: turnCount.isEven ? 0 : 1,
        players: players,
        history: history,
        status: MatchStatus.active,
      );

      final old = OldSharedPreferencesApproach();
      old.saveMatchState(state);
      return (state, old);
    }

    // ──────────────────────────────────────────────────────
    //  OLD APPROACH: shared_preferences (JSON blob)
    // ──────────────────────────────────────────────────────

    test('OLD: Save turn (serialize full JSON blob)', () async {
      for (final turnCount in [10, 50, 100, 200]) {
        final (state, old) = buildState(turnCount);
        final sw = Stopwatch()..start();

        // Simulate recording one more turn: re-serialize entire state
        final newTurn = makeTurn(turnCount, playerIds[turnCount % 2], 200);
        final newHistory = [...state.history, newTurn];
        final updated = state.copyWith(history: newHistory);
        old.saveMatchState(updated);

        sw.stop();
        print('  [OLD] turnCount=$turnCount  save=${sw.elapsedMicroseconds}µs  '
            'blobSize=${old.blobSize} bytes');
      }
    });

    test('OLD: Load match (deserialize JSON blob)', () async {
      for (final turnCount in [10, 50, 100, 200]) {
        final (state, old) = buildState(turnCount);
        final sw = Stopwatch()..start();

        final loaded = old.loadMatchState();

        sw.stop();
        assert(loaded != null);
        print('  [OLD] turnCount=$turnCount  load=${sw.elapsedMicroseconds}µs  '
            'turnsReplayed=${loaded!.history.length}');
      }
    });

    test('OLD: Undo turn (load + pop + re-save)', () async {
      for (final turnCount in [10, 50, 100, 200]) {
        final (state, old) = buildState(turnCount);
        final sw = Stopwatch()..start();

        old.undoLastTurn();

        sw.stop();
        print('  [OLD] turnCount=$turnCount  undo=${sw.elapsedMicroseconds}µs');
      }
    });

    // ──────────────────────────────────────────────────────
    //  NEW APPROACH: thingd (event-sourced)
    // ──────────────────────────────────────────────────────

    test('NEW: Save turn (append single event)', () async {
      final dir = await getApplicationDocumentsDirectory();
      final thingd = await ThingdService.open();
      final matchId = 'bench_${uuid.v4()}';

      // Setup match config
      await thingd.saveMatchConfig(matchId, 501, playerNames);
      await thingd.setActiveMatchId(matchId);

      for (final turnCount in [10, 50, 100, 200]) {
        // Pre-populate with turnCount turns
        for (int i = 0; i < turnCount; i++) {
          final pid = i.isEven ? playerIds[0] : playerIds[1];
          final turn = makeTurn(i, pid, 300);
          await thingd.appendTurn(matchId, turn);
        }

        final sw = Stopwatch()..start();

        // Record one more turn — just appends one event
        final newTurn = makeTurn(turnCount, playerIds[turnCount % 2], 200);
        await thingd.appendTurn(matchId, newTurn);

        sw.stop();
        print('  [NEW] turnCount=$turnCount  save=${sw.elapsedMicroseconds}µs');
      }

      await thingd.clearAll();
    });

    test('NEW: Load match (list events + replay)', () async {
      final thingd = await ThingdService.open();
      final matchId = 'bench_load_${uuid.v4()}';
      await thingd.saveMatchConfig(matchId, 501, playerNames);

      for (final turnCount in [10, 50, 100, 200]) {
        // Pre-populate
        for (int i = 0; i < turnCount; i++) {
          final pid = i.isEven ? playerIds[0] : playerIds[1];
          final turn = makeTurn(i, pid, 300);
          await thingd.appendTurn(matchId, turn);
        }

        final sw = Stopwatch()..start();

        // Load: list all events + replay
        final turns = await thingd.listTurns(matchId);

        sw.stop();
        print('  [NEW] turnCount=$turnCount  load=${sw.elapsedMicroseconds}µs  '
            'events=${turns.length}');

        // Cleanup for next iteration
        await thingd.deleteMatch(matchId);
      }
    });

    test('NEW: Undo turn (delete_last_event)', () async {
      final thingd = await ThingdService.open();
      final matchId = 'bench_undo_${uuid.v4()}';
      await thingd.saveMatchConfig(matchId, 501, playerNames);

      for (final turnCount in [10, 50, 100, 200]) {
        // Pre-populate
        for (int i = 0; i < turnCount; i++) {
          final pid = i.isEven ? playerIds[0] : playerIds[1];
          final turn = makeTurn(i, pid, 300);
          await thingd.appendTurn(matchId, turn);
        }

        final sw = Stopwatch()..start();

        // Undo: just delete the last event
        await thingd.undoLastTurn(matchId);

        sw.stop();
        print('  [NEW] turnCount=$turnCount  undo=${sw.elapsedMicroseconds}µs');

        await thingd.deleteMatch(matchId);
      }
    });

    // ──────────────────────────────────────────────────────
    //  SIZE COMPARISON
    // ──────────────────────────────────────────────────────

    test('Storage size: JSON blob vs event list', () async {
      final thingd = await ThingdService.open();

      for (final turnCount in [10, 50, 100, 200]) {
        // OLD: full JSON blob size
        final (state, old) = buildState(turnCount);
        final blobSize = old.blobSize;

        // NEW: sum of all event body sizes
        final matchId = 'bench_size_${uuid.v4()}';
        await thingd.saveMatchConfig(matchId, 501, playerNames);
        for (int i = 0; i < turnCount; i++) {
          final pid = i.isEven ? playerIds[0] : playerIds[1];
          final turn = makeTurn(i, pid, 300);
          await thingd.appendTurn(matchId, turn);
        }
        final turns = await thingd.listTurns(matchId);
        final eventSize = turns.fold(
          0,
          (sum, t) => sum + utf8.encode(jsonEncode(t.toJson())).length,
        );

        // Config overhead (stored once)
        final configSize =
            utf8.encode(jsonEncode({'gameType': 501, 'playerNames': playerNames})).length;

        print('  turnCount=$turnCount  '
            'OLD_blob=${blobSize}B  '
            'NEW_events=${eventSize}B + config=${configSize}B  '
            'ratio=${(eventSize / blobSize * 100).toStringAsFixed(1)}%');

        await thingd.deleteMatch(matchId);
      }
    });
  });
}
