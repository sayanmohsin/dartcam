import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/match_state.dart';
import '../models/player_profile.dart';
import '../models/turn_mutation.dart';
import '../../core/constants/dartboard_constants.dart';
import '../../core/vision/dartboard_scorer.dart';
import '../../services/thingd_service.dart';

class MatchStateManager extends ValueNotifier<DartMatchState> {
  final ThingdService _thingd;
  String matchId;

  ThingdService get thingd => _thingd;

  MatchStateManager._({
    required DartMatchState state,
    required ThingdService thingd,
    required this.matchId,
  })  : _thingd = thingd,
        super(state);

  /// Create a new match and persist it to thingd.
  static Future<MatchStateManager> create({
    required ThingdService thingd,
    required List<String> playerNames,
    int gameType = DartboardConstants.defaultGameType,
  }) async {
    final matchId = const Uuid().v4();
    final state = DartMatchState(
      gameType: gameType,
      activePlayerIndex: 0,
      players: playerNames
          .map((name) => PlayerProfile(
                id: const Uuid().v4(),
                name: name,
                currentScore: gameType,
              ))
          .toList(),
      history: [],
      status: MatchStatus.active,
    );

    await thingd.saveMatchConfig(matchId, gameType, playerNames);
    await thingd.setActiveMatchId(matchId);

    return MatchStateManager._(
      state: state,
      thingd: thingd,
      matchId: matchId,
    );
  }

  /// Load the active match from thingd by replaying events.
  /// Returns null if no active match exists.
  static Future<MatchStateManager?> load(ThingdService thingd) async {
    final matchId = await thingd.getActiveMatchId();
    if (matchId == null) return null;

    final config = await thingd.getMatchConfig(matchId);
    if (config == null) return null;

    final gameType = config['gameType'] as int;
    final playerNames = List<String>.from(config['playerNames'] as List);

    final turns = await thingd.listTurns(matchId);

    // Rebuild state by replaying events
    var activePlayerIndex = 0;
    var players = playerNames
        .map((name) => PlayerProfile(
              id: const Uuid().v4(),
              name: name,
              currentScore: gameType,
            ))
        .toList();

    final history = <TurnMutation>[];

    for (final turn in turns) {
      // Find the player and apply the turn
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

  static Future<void> clear(ThingdService thingd) async {
    await thingd.clearAll();
  }

  void advanceTurn() {
    if (value.isCompleted) return;
    final nextIndex = (value.activePlayerIndex + 1) % value.players.length;
    value = value.copyWith(activePlayerIndex: nextIndex);
  }

  /// Records a turn. Returns a BustResult if the turn was a bust.
  Future<BustResult> recordTurn(List<int> scores, {List<ScoredDart>? darts}) async {
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

    final mutation = TurnMutation(
      playerId: player.id,
      detectedScores: List.unmodifiable(scores),
      totalTurnScore: totalScore,
      scoreBeforeTurn: scoreBefore,
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

    // Persist event to thingd
    await _thingd.appendTurn(matchId, mutation);

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

    // Delete last event from thingd
    await _thingd.undoLastTurn(matchId);
  }

  bool get canUndo => value.history.isNotEmpty;

  Future<void> resetMatch({int? gameType}) async {
    final newGameType = gameType ?? value.gameType;
    final playerNames = value.players.map((p) => p.name).toList();

    // Delete old match stream and create new match
    await _thingd.deleteMatch(matchId);

    final newMatchId = const Uuid().v4();
    await _thingd.saveMatchConfig(newMatchId, newGameType, playerNames);
    await _thingd.setActiveMatchId(newMatchId);

    matchId = newMatchId;

    value = DartMatchState(
      gameType: newGameType,
      activePlayerIndex: 0,
      players: playerNames
          .map((name) => PlayerProfile(
                id: const Uuid().v4(),
                name: name,
                currentScore: newGameType,
              ))
          .toList(),
      history: [],
      status: MatchStatus.active,
    );
  }

  Future<void> endMatch() async {
    await _thingd.deleteMatch(matchId);
    await _thingd.setActiveMatchId(null);
  }
}

enum BustResult { none, overBust, oneBust, notDouble }
