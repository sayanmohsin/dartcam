import '../data/models/detection_log.dart';
import '../data/models/player_profile.dart';
import '../data/models/turn_mutation.dart';

/// Abstract interface for the thingd persistence layer.
///
/// Both the real [ThingdService] and test fakes implement this.
abstract class ThingdServiceInterface {
  // Match config
  Future<void> saveMatchConfig(String matchId, int gameType, List<String> playerNames);
  Future<Map<String, dynamic>?> getMatchConfig(String matchId);

  // Turn events
  Future<void> appendTurn(String matchId, TurnMutation turn);
  Future<List<TurnMutation>> listTurns(String matchId);
  Future<void> undoLastTurn(String matchId);
  Future<void> deleteMatch(String matchId);
  Future<void> completeMatch(String matchId, {required String winnerPlayerId, required int totalTurns});

  // Active match
  Future<String?> getActiveMatchId();
  Future<void> setActiveMatchId(String? matchId);

  // Sequence tracking
  int? getLastSequence(String matchId);
  void setLastSequence(String matchId, int sequence);

  // Player profiles
  Future<void> savePlayerProfile(PlayerProfile profile);
  Future<PlayerProfile?> getPlayerProfile(String id);
  Future<List<PlayerProfile>> listPlayerProfiles();

  // Detection logs
  Future<void> appendDetectionLog(String matchId, DetectionLog log);

  // Graph links
  Future<void> linkPlayerToMatch(String playerId, String matchId);

  // Lifecycle
  Future<void> clearAll();
}
