import 'dart:convert';

import 'package:path_provider/path_provider.dart';

import '../data/models/turn_mutation.dart';
import '../src/rust/api/bridge.dart';
import '../src/rust/frb_generated.dart';

class ThingdService {
  final ThingdBridge _bridge;

  ThingdService._(this._bridge);

  static Future<ThingdService> open() async {
    await RustLib.init();
    final dir = await getApplicationDocumentsDirectory();
    final bridge = await ThingdBridge.open(path: '${dir.path}/thingd.db');
    return ThingdService._(bridge);
  }

  // ── Match config (ObjectStore) ──────────────────────────────────────

  Future<void> saveMatchConfig(
    String matchId,
    int gameType,
    List<String> playerNames,
  ) async {
    final body = jsonEncode({
      'gameType': gameType,
      'playerNames': playerNames,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _bridge.putObject(collection: 'matches', id: matchId, body: body);
  }

  Future<Map<String, dynamic>?> getMatchConfig(String matchId) async {
    final body = await _bridge.getObject(
      collection: 'matches',
      id: matchId,
    );
    if (body == null) return null;
    return jsonDecode(body) as Map<String, dynamic>;
  }

  // ── Turn events (EventLog) ──────────────────────────────────────────

  Future<void> appendTurn(String matchId, TurnMutation turn) async {
    final body = jsonEncode(turn.toJson());
    await _bridge.appendEvent(
      stream: 'match_$matchId',
      eventType: 'turn.recorded',
      body: body,
    );
  }

  Future<List<TurnMutation>> listTurns(String matchId) async {
    final bodies = await _bridge.listEvents(stream: 'match_$matchId');
    return bodies
        .map((b) => TurnMutation.fromJson(jsonDecode(b) as Map<String, dynamic>))
        .toList();
  }

  Future<void> undoLastTurn(String matchId) async {
    await _bridge.deleteLastEvent(stream: 'match_$matchId');
  }

  Future<void> deleteMatch(String matchId) async {
    await _bridge.deleteStream(stream: 'match_$matchId');
    await _bridge.deleteObject(collection: 'matches', id: matchId);
  }

  // ── Active match pointer (ObjectStore) ──────────────────────────────

  Future<String?> getActiveMatchId() async {
    final body = await _bridge.getObject(
      collection: 'active_match',
      id: 'current',
    );
    if (body == null) return null;
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['matchId'] as String?;
  }

  Future<void> setActiveMatchId(String? matchId) async {
    if (matchId == null) {
      await _bridge.deleteObject(collection: 'active_match', id: 'current');
    } else {
      final body = jsonEncode({'matchId': matchId});
      await _bridge.putObject(
        collection: 'active_match',
        id: 'current',
        body: body,
      );
    }
  }

  // ── Cleanup ─────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    final matchId = await getActiveMatchId();
    if (matchId != null) {
      await deleteMatch(matchId);
    }
    await _bridge.deleteObject(collection: 'active_match', id: 'current');
  }
}
