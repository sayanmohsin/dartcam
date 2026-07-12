import 'dart:convert';

import '../data/models/cloud_credentials.dart';
import '../data/models/match_state.dart';
import 'cloud_auth_service.dart';

class CloudUsageService {
  final CloudAuthService _auth;

  CloudUsageService(this._auth);

  /// Push a completed match result to the thingd.cloud object store.
  ///
  /// Only called when a match ends. Stores aggregate data only —
  /// no individual turns or per-dart scores.
  Future<bool> pushMatchResult(
    CloudCredentials creds,
    String matchId,
    DartMatchState state,
  ) async {
    if (!state.isCompleted) return false;

    final winner = state.players[state.activePlayerIndex];
    final result = await _auth.put(
      creds.serverUrl,
      creds.apiKey,
      '/v1/objects/match_results/$matchId',
      {
        'matchId': matchId,
        'gameType': state.gameType,
        'totalTurns': state.history.length,
        'winner': winner.name,
        'winnerScore': winner.currentScore,
        'players':
            state.players.map((p) => {'name': p.name, 'finalScore': p.currentScore}).toList(),
        'completedAt': DateTime.now().toIso8601String(),
      },
    );
    return result != null;
  }

  /// Push a player's aggregate stats to the cloud.
  Future<bool> pushPlayerStats(
    CloudCredentials creds,
    String playerId,
    Map<String, dynamic> stats,
  ) async {
    final result = await _auth.put(
      creds.serverUrl,
      creds.apiKey,
      '/v1/objects/player_stats/$playerId',
      {
        'playerId': playerId,
        ...stats,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
    return result != null;
  }

  /// Fetch a player's stats from the cloud.
  Future<Map<String, dynamic>?> fetchPlayerStats(
    CloudCredentials creds,
    String playerId,
  ) async {
    final result = await _auth.get(
      creds.serverUrl,
      creds.apiKey,
      '/v1/objects/player_stats/$playerId',
    );
    return result;
  }

  /// Fetch all match results from the cloud (for leaderboard/history).
  Future<List<Map<String, dynamic>>> fetchMatchHistory(
    CloudCredentials creds,
  ) async {
    final result = await _auth.get(
      creds.serverUrl,
      creds.apiKey,
      '/v1/objects?collection=match_results&limit=100&sortBy=completedAt&sortDir=desc',
    );
    if (result == null) return [];
    final data = result['data'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }
}
