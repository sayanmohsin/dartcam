import 'player_profile.dart';
import 'turn_mutation.dart';

enum MatchStatus { active, completed }

class DartMatchState {
  final int gameType;
  final int activePlayerIndex;
  final List<PlayerProfile> players;
  final List<TurnMutation> history;
  final MatchStatus status;

  const DartMatchState({
    required this.gameType,
    required this.activePlayerIndex,
    required this.players,
    required this.history,
    required this.status,
  });

  DartMatchState copyWith({
    int? gameType,
    int? activePlayerIndex,
    List<PlayerProfile>? players,
    List<TurnMutation>? history,
    MatchStatus? status,
  }) {
    return DartMatchState(
      gameType: gameType ?? this.gameType,
      activePlayerIndex: activePlayerIndex ?? this.activePlayerIndex,
      players: players ?? this.players,
      history: history ?? this.history,
      status: status ?? this.status,
    );
  }

  PlayerProfile get activePlayer => players[activePlayerIndex];

  bool get isCompleted => status == MatchStatus.completed;
}
