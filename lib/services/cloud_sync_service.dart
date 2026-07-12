import 'dart:convert';

import '../data/models/cloud_credentials.dart';
import '../data/models/turn_mutation.dart';
import 'cloud_auth_service.dart';

class CloudSyncService {
  final CloudAuthService _auth;

  CloudSyncService(this._auth);

  /// Push a single turn event to the thingd.cloud event stream.
  Future<bool> pushTurn(
    CloudCredentials creds,
    String matchId,
    TurnMutation turn,
  ) async {
    final result = await _auth.post(
      creds.serverUrl,
      creds.apiKey,
      '/v1/events/match_$matchId',
      {
        'type': 'turn.recorded',
        'body': turn.toJson(),
      },
    );
    return result != null;
  }

  /// Push the match config to thingd.cloud object store.
  Future<bool> pushMatchConfig(
    CloudCredentials creds,
    String matchId,
    Map<String, dynamic> config,
  ) async {
    final result = await _auth.put(
      creds.serverUrl,
      creds.apiKey,
      '/v1/objects/matches/$matchId',
      config,
    );
    return result != null;
  }

  /// Fetch turn events for a match from thingd.cloud.
  Future<List<TurnMutation>> fetchTurns(
    CloudCredentials creds,
    String matchId,
  ) async {
    final result = await _auth.get(
      creds.serverUrl,
      creds.apiKey,
      '/v1/events?stream=match_$matchId',
    );
    if (result == null) return [];

    final data = result['data'];
    if (data is! List) return [];

    final turns = <TurnMutation>[];
    for (final item in data) {
      if (item is Map && item['body'] is Map) {
        turns.add(TurnMutation.fromJson(
            Map<String, dynamic>.from(item['body'] as Map)));
      }
    }
    return turns;
  }

  /// Fetch match config from thingd.cloud.
  Future<Map<String, dynamic>?> fetchMatchConfig(
    CloudCredentials creds,
    String matchId,
  ) async {
    final result = await _auth.get(
      creds.serverUrl,
      creds.apiKey,
      '/v1/objects/matches/$matchId',
    );
    if (result == null) return null;
    final data = result['data'];
    if (data is! Map) return null;
    return Map<String, dynamic>.from(data);
  }

  /// Push active match pointer to thingd.cloud.
  Future<bool> pushActiveMatchId(
    CloudCredentials creds,
    String matchId,
  ) async {
    final result = await _auth.put(
      creds.serverUrl,
      creds.apiKey,
      '/v1/objects/active_match/current',
      {'matchId': matchId},
    );
    return result != null;
  }
}
