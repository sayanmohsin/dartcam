import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/match_state.dart';
import '../models/player_profile.dart';
import '../models/turn_mutation.dart';
import '../../core/constants/dartboard_constants.dart';
import '../../core/vision/scoring_geometry.dart';

const _matchKey = 'saved_match';

class MatchStateManager extends ValueNotifier<DartMatchState> {
  MatchStateManager({
    required List<String> playerNames,
    int gameType = DartboardConstants.defaultGameType,
  }) : super(DartMatchState(
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
        )) {
    _save();
  }

  MatchStateManager._fromState(super.state) : super() {
    _save();
  }

  static Future<MatchStateManager?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_matchKey);
    if (json == null) return null;
    try {
      final state = DartMatchState.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      if (state.isCompleted) return null;
      return MatchStateManager._fromState(state);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_matchKey, jsonEncode(value.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_matchKey);
  }

  void advanceTurn() {
    if (value.isCompleted) return;
    final nextIndex = (value.activePlayerIndex + 1) % value.players.length;
    value = value.copyWith(activePlayerIndex: nextIndex);
    _save();
  }

  /// Records a turn. Returns a BustResult if the turn was a bust.
  BustResult recordTurn(List<int> scores, {List<ScoredDart>? darts}) {
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

    if (!isComplete) {
      advanceTurn();
    }

    _save();
    return BustResult.none;
  }

  void undoLastTurn() {
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

    _save();
  }

  bool get canUndo => value.history.isNotEmpty;

  void resetMatch({int? gameType}) {
    final newGameType = gameType ?? value.gameType;
    final playerNames = value.players.map((p) => p.name).toList();
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
    _save();
  }

  void endMatch() {
    clear();
  }
}

enum BustResult { none, overBust, oneBust, notDouble }
