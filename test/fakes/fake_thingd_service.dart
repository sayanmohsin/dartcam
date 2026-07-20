import 'dart:convert';

import 'package:local_dart_scorer/data/models/detection_log.dart';
import 'package:local_dart_scorer/data/models/player_profile.dart';
import 'package:local_dart_scorer/data/models/turn_mutation.dart';
import 'package:local_dart_scorer/services/thingd_service_interface.dart';

/// In-memory fake implementation of ThingdService for unit tests.
///
/// Stores all data in Dart Maps — no Rust or SQLite dependency.
class FakeThingdService implements ThingdServiceInterface {
  final Map<String, Map<String, dynamic>> _objects = {};
  final Map<String, List<String>> _eventStreams = {};
  final Map<String, int> _lastSequences = {};
  String? _activeMatchId;

  // ── Match config ──

  @override
  Future<void> saveMatchConfig(
    String matchId,
    int gameType,
    List<String> playerNames,
  ) async {
    _objects['matches'] ??= {};
    _objects['matches']![matchId] = {
      'gameType': gameType,
      'playerNames': playerNames,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>?> getMatchConfig(String matchId) async {
    final config = _objects['matches']?[matchId];
    if (config == null) return null;
    return Map<String, dynamic>.from(config as Map);
  }

  // ── Turn events ──

  @override
  Future<void> appendTurn(String matchId, TurnMutation turn) async {
    _eventStreams['match_$matchId'] ??= [];
    _eventStreams['match_$matchId']!.add(jsonEncode(turn.toJson()));
  }

  @override
  Future<List<TurnMutation>> listTurns(String matchId) async {
    final bodies = _eventStreams['match_$matchId'] ?? [];
    return bodies
        .map((b) => TurnMutation.fromJson(jsonDecode(b) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> undoLastTurn(String matchId) async {
    _eventStreams['match_$matchId']?.removeLast();
  }

  @override
  Future<void> deleteMatch(String matchId) async {
    _eventStreams.remove('match_$matchId');
    _objects['matches']?.remove(matchId);
    _lastSequences.remove(matchId);
  }

  @override
  Future<void> completeMatch(
    String matchId, {
    required String winnerPlayerId,
    required int totalTurns,
  }) async {
    final config = _objects['matches']?[matchId];
    if (config == null) return;
    (config as Map)['completedAt'] = DateTime.now().toIso8601String();
    (config)['winnerPlayerId'] = winnerPlayerId;
    (config)['totalTurns'] = totalTurns;
  }

  // ── Active match ──

  @override
  Future<String?> getActiveMatchId() async => _activeMatchId;

  @override
  Future<void> setActiveMatchId(String? matchId) async {
    _activeMatchId = matchId;
  }

  // ── Sequence tracking ──

  @override
  int? getLastSequence(String matchId) => _lastSequences[matchId];

  @override
  void setLastSequence(String matchId, int sequence) {
    _lastSequences[matchId] = sequence;
  }

  // ── Player profiles ──

  @override
  Future<void> savePlayerProfile(PlayerProfile profile) async {
    _objects['players'] ??= {};
    _objects['players']![profile.id] = profile.toJson();
  }

  @override
  Future<PlayerProfile?> getPlayerProfile(String id) async {
    final data = _objects['players']?[id];
    if (data == null) return null;
    return PlayerProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<List<PlayerProfile>> listPlayerProfiles() async {
    final profiles = _objects['players'] ?? <String, dynamic>{};
    return profiles.values
        .map((data) => PlayerProfile.fromJson(Map<String, dynamic>.from(data as Map)))
        .toList();
  }

  // ── Detection logs ──

  @override
  Future<void> appendDetectionLog(String matchId, DetectionLog log) async {
    _eventStreams['${matchId}_detect'] ??= [];
    _eventStreams['${matchId}_detect']!.add(jsonEncode(log.toJson()));
  }

  // ── Graph links ──

  final Map<String, List<({String fromRef, String linkType, String toRef})>> _links = {};

  @override
  Future<void> linkPlayerToMatch(String playerId, String matchId) async {
    _links.putIfAbsent('player_$playerId', () => []);
    _links['player_$playerId']!.add((
      fromRef: 'player_$playerId',
      linkType: 'played',
      toRef: 'match_$matchId',
    ));
  }

  // ── Cleanup ──

  @override
  Future<void> clearAll() async {
    _objects.clear();
    _eventStreams.clear();
    _lastSequences.clear();
    _activeMatchId = null;
    _links.clear();
  }
}
