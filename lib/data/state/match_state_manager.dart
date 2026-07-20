import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/match_state.dart';
import '../models/player_profile.dart';
import '../models/turn_mutation.dart';
import '../../core/constants/dartboard_constants.dart';
import '../../core/vision/dartboard_scorer.dart';
import '../../services/thingd_service_interface.dart';

class MatchStateManager extends ValueNotifier<DartMatchState> {
  final ThingdServiceInterface _thingd;
  String matchId;

  /// Accumulated stats keyed by player ID during the match.
  final Map<String, _AccumulatedStats> _accStats = {};

  ThingdServiceInterface get thingd => _thingd;

  MatchStateManager._({
    required DartMatchState state,
    required ThingdServiceInterface thingd,
    required this.matchId,
  })  : _thingd = thingd,
        super(state);

  /// Create a new match, loading existing profiles for known names.
  static Future<MatchStateManager> create({
    required ThingdServiceInterface thingd,
    required List<String> playerNames,
    int gameType = DartboardConstants.defaultGameType,
  }) async {
    // Load existing profiles to reuse stable player IDs
    final existing = await _loadExistingProfiles(thingd);
    final matchId = const Uuid().v4();

    final players = playerNames.map((name) {
      // Reuse existing profile if name matches
      final match = existing[name.toLowerCase()];
      if (match != null) {
        return match.copyWith(currentScore: gameType);
      }
      return PlayerProfile(
        id: const Uuid().v4(),
        name: name,
        currentScore: gameType,
      );
    }).toList();

    final state = DartMatchState(
      gameType: gameType,
      activePlayerIndex: 0,
      players: players,
      history: [],
      status: MatchStatus.active,
    );

    await thingd.saveMatchConfig(matchId, gameType, playerNames);
    await thingd.setActiveMatchId(matchId);

    // Save player profiles so load can find them by ID
    for (final player in players) {
      await thingd.savePlayerProfile(player);
    }

    return MatchStateManager._(
      state: state,
      thingd: thingd,
      matchId: matchId,
    );
  }

  /// Load the active match from thingd by replaying events.
  /// Returns null if no active match exists.
  static Future<MatchStateManager?> load(ThingdServiceInterface thingd) async {
    final matchId = await thingd.getActiveMatchId();
    if (matchId == null) return null;

    final config = await thingd.getMatchConfig(matchId);
    if (config == null) return null;

    final gameType = config['gameType'] as int;
    final playerNames = List<String>.from(config['playerNames'] as List);

    // Load existing profiles to get stable IDs and lifetime stats
    final existing = await _loadExistingProfiles(thingd);
    final turns = await thingd.listTurns(matchId);

    var activePlayerIndex = 0;
    var players = playerNames.map((name) {
      final match = existing[name.toLowerCase()];
      if (match != null) {
        return match.copyWith(currentScore: gameType);
      }
      return PlayerProfile(
        id: const Uuid().v4(),
        name: name,
        currentScore: gameType,
      );
    }).toList();

    final history = <TurnMutation>[];

    if (turns.isNotEmpty) {
      thingd.setLastSequence(matchId, turns.length);
    }

    for (final turn in turns) {
      final playerIndex = players.indexWhere((p) => p.id == turn.playerId);
      if (playerIndex < 0) continue;

      final updatedPlayers = List<PlayerProfile>.from(players);
      updatedPlayers[playerIndex] = updatedPlayers[playerIndex].copyWith(
        currentScore: turn.scoreBeforeTurn - turn.totalTurnScore,
      );

      players = updatedPlayers;
      history.add(turn);
      activePlayerIndex = playerIndex;
    }

    final isCompleted = players.any((p) => p.currentScore == 0);
    final state = DartMatchState(
      gameType: gameType,
      activePlayerIndex: activePlayerIndex,
      players: players,
      history: history,
      status: isCompleted ? MatchStatus.completed : MatchStatus.active,
    );

    if (state.isCompleted) return null;

    return MatchStateManager._(
      state: state,
      thingd: thingd,
      matchId: matchId,
    );
  }

  static Future<void> clear(ThingdServiceInterface thingd) async {
    await thingd.clearAll();
  }

  void advanceTurn() {
    if (value.isCompleted) return;
    final nextIndex = (value.activePlayerIndex + 1) % value.players.length;
    value = value.copyWith(activePlayerIndex: nextIndex);
  }

  /// Records a turn. Returns a BustResult if the turn was a bust.
  Future<BustResult> recordTurn(
    List<int> scores, {
    List<ScoredDart>? darts,
    bool isAutoDetected = false,
  }) async {
    if (value.isCompleted) return BustResult.none;

    final player = value.activePlayer;
    final scoreBefore = player.currentScore;
    final totalScore = scores.fold(0, (sum, s) => sum + s);
    final newScore = scoreBefore - totalScore;

    final isOverBust = newScore < 0;
    final isOneBust = newScore == 1;
    final isCheckout = newScore == 0;

    bool isBust = isOverBust || isOneBust;

    if (isCheckout && !isBust) {
      if (darts != null && darts.isNotEmpty) {
        ScoredDart? checkoutDart;
        for (int i = darts.length - 1; i >= 0; i--) {
          if (darts[i].totalScore > 0) {
            checkoutDart = darts[i];
            break;
          }
        }
        if (checkoutDart != null &&
            checkoutDart.multiplier != 2 &&
            checkoutDart.score != 50) {
          isBust = true;
        }
      }
    }

    if (isBust) {
      advanceTurn();
      return isOverBust
          ? BustResult.overBust
          : (isOneBust ? BustResult.oneBust : BustResult.notDouble);
    }

    // Track stats (even non-checkout turns)
    _accStats[player.id] ??= _AccumulatedStats();
    _accStats[player.id]!.dartsThisMatch += scores.length;
    if (totalScore == 180) _accStats[player.id]!.eightiesThisMatch++;
    if (totalScore >= 100) _accStats[player.id]!.centuriesThisMatch++;
    if (isCheckout && totalScore > _accStats[player.id]!.bestCheckout) {
      _accStats[player.id]!.bestCheckout = totalScore;
    }

    final mutation = TurnMutation(
      playerId: player.id,
      detectedScores: List.unmodifiable(scores),
      totalTurnScore: totalScore,
      scoreBeforeTurn: scoreBefore,
      dartLabels: darts?.map((d) => d.label).toList(),
      dartMultipliers: darts?.map((d) => d.multiplier).toList(),
      isAutoDetected: isAutoDetected,
    );

    final updatedPlayers = List<PlayerProfile>.from(value.players);
    updatedPlayers[value.activePlayerIndex] =
        player.copyWith(currentScore: newScore);

    final updatedHistory = List<TurnMutation>.from(value.history)
      ..add(mutation);

    final isComplete = newScore == 0;

    value = value.copyWith(
      players: updatedPlayers,
      history: updatedHistory,
      status: isComplete ? MatchStatus.completed : MatchStatus.active,
    );

    await _thingd.appendTurn(matchId, mutation);

    if (isComplete) {
      await _thingd.completeMatch(
        matchId,
        winnerPlayerId: player.id,
        totalTurns: value.history.length + 1,
      );
      await _persistPlayerProfiles(player.id);
      await _linkPlayersToMatch();
    }

    if (!isComplete) {
      advanceTurn();
    }

    return BustResult.none;
  }

  Future<void> undoLastTurn() async {
    if (value.history.isEmpty) return;

    final lastMutation = value.history.last;
    final updatedPlayers = List<PlayerProfile>.from(value.players);

    for (int i = 0; i < updatedPlayers.length; i++) {
      if (updatedPlayers[i].id == lastMutation.playerId) {
        updatedPlayers[i] = updatedPlayers[i]
            .copyWith(currentScore: lastMutation.scoreBeforeTurn);
        break;
      }
    }

    final updatedHistory = List<TurnMutation>.from(value.history)
      ..removeLast();

    final targetIndex = updatedPlayers.indexWhere(
      (p) => p.id == lastMutation.playerId,
    );

    value = value.copyWith(
      players: updatedPlayers,
      history: updatedHistory,
      activePlayerIndex:
          targetIndex >= 0 ? targetIndex : value.activePlayerIndex,
      status: MatchStatus.active,
    );

    await _thingd.undoLastTurn(matchId);
  }

  bool get canUndo => value.history.isNotEmpty;

  Future<void> resetMatch({int? gameType}) async {
    final newGameType = gameType ?? value.gameType;
    final playerNames = value.players.map((p) => p.name).toList();

    await _thingd.deleteMatch(matchId);

    final newMatchId = const Uuid().v4();
    await _thingd.saveMatchConfig(newMatchId, newGameType, playerNames);
    await _thingd.setActiveMatchId(newMatchId);

    _accStats.clear();
    matchId = newMatchId;

    // Reuse existing profile IDs
    final existing = await _loadExistingProfiles(_thingd);
    value = DartMatchState(
      gameType: newGameType,
      activePlayerIndex: 0,
      players: playerNames.map((name) {
        final match = existing[name.toLowerCase()];
        if (match != null) {
          return match.copyWith(currentScore: newGameType);
        }
        return PlayerProfile(
          id: const Uuid().v4(),
          name: name,
          currentScore: newGameType,
        );
      }).toList(),
      history: [],
      status: MatchStatus.active,
    );
  }

  Future<void> endMatch() async {
    await _thingd.deleteMatch(matchId);
    await _thingd.setActiveMatchId(null);
    _accStats.clear();
  }

  // ── Private helpers ────────────────────────────────────────────────

  /// Load all existing profiles indexed by lowercased name.
  static Future<Map<String, PlayerProfile>> _loadExistingProfiles(
    ThingdServiceInterface thingd,
  ) async {
    final profiles = await thingd.listPlayerProfiles();
    final map = <String, PlayerProfile>{};
    for (final p in profiles) {
      map[p.name.toLowerCase()] = p;
    }
    return map;
  }

  /// Persist updated player profiles after a match completes.
  Future<void> _persistPlayerProfiles(String winnerId) async {
    for (final player in value.players) {
      final acc = _accStats[player.id] ?? _AccumulatedStats();
      // Load existing lifetime stats from thingd
      final existing = await _thingd.getPlayerProfile(player.id);

      final updated = (existing ?? player).copyWith(
        totalMatches: (existing?.totalMatches ?? 0) + 1,
        totalWins: (existing?.totalWins ?? 0) + (player.id == winnerId ? 1 : 0),
        totalDartsThrown:
            (existing?.totalDartsThrown ?? 0) + acc.dartsThisMatch,
        oneEightyCount:
            (existing?.oneEightyCount ?? 0) + acc.eightiesThisMatch,
        centuryCount:
            (existing?.centuryCount ?? 0) + acc.centuriesThisMatch,
        highestCheckout: _max(
          existing?.highestCheckout ?? 0,
          acc.bestCheckout,
        ),
      );

      await _thingd.savePlayerProfile(updated);
    }
    _accStats.clear();
  }

  /// Link all players to this match in the graph.
  Future<void> _linkPlayersToMatch() async {
    for (final player in value.players) {
      await _thingd.linkPlayerToMatch(player.id, matchId);
    }
  }

  static int _max(int a, int b) => a > b ? a : b;
}

/// Per-player stats accumulated during a match.
class _AccumulatedStats {
  int dartsThisMatch = 0;
  int eightiesThisMatch = 0;
  int centuriesThisMatch = 0;
  int bestCheckout = 0;
}

enum BustResult { none, overBust, oneBust, notDouble }
