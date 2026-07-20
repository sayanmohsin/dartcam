import 'dart:convert';

import '../data/models/cloud_credentials.dart';
import '../data/models/match_state.dart';
import 'cloud_auth_service.dart';

class CloudUsageService {
  final CloudAuthService _auth;

  CloudUsageService(this._auth);

  /// Push a completed match result to the thingd.cloud object store.
  ///
  /// Data is scoped by email in the object path.
  Future<bool> pushMatchResult(
    CloudCredentials creds,
    String email,
    String matchId,
    DartMatchState state,
  ) async {
    if (!state.isCompleted) return false;

    final winner = state.players[state.activePlayerIndex];
    final result = await _auth.put(
      creds.serverUrl,
      creds.apiKey,
      '/v1/objects/match_results/${email}_$matchId',
      {
        'email': email,
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

  /// Push a player's aggregate stats to the cloud, scoped by email.
  Future<bool> pushPlayerStats(
    CloudCredentials creds,
    String email,
    String playerId,
    Map<String, dynamic> stats,
  ) async {
    final result = await _auth.put(
      creds.serverUrl,
      creds.apiKey,
      '/v1/objects/player_stats/${email}_$playerId',
      {
        'email': email,
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
    String email,
    String playerId,
  ) async {
    final result = await _auth.get(
      creds.serverUrl,
      creds.apiKey,
      '/v1/objects/player_stats/${email}_$playerId',
    );
    return result;
  }

  /// Fetch match results for a specific email.
  Future<List<Map<String, dynamic>>> fetchMatchHistory(
    CloudCredentials creds,
    String email,
  ) async {
    final result = await _auth.get(
      creds.serverUrl,
      creds.apiKey,
      '/v1/objects?collection=match_results&limit=100&sortBy=completedAt&sortDir=desc',
    );
    if (result == null) return [];
    final data = result['data'];
    if (data is! List) return [];
    // Filter by email client-side
    final filtered = data.where((item) {
      final body = item['body'] as Map<String, dynamic>?;
      return body?['email'] == email;
    }).toList();
    return filtered.cast<Map<String, dynamic>>();
  }
}
