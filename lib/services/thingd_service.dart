import 'dart:convert';

import 'package:path_provider/path_provider.dart';

import '../data/models/turn_mutation.dart';
import '../src/rust/api/bridge.dart';
import '../src/rust/frb_generated.dart';

class ThingdService {
  final ThingdBridge _bridge;

  /// Cached last-known event sequence per match stream for incremental replay.
  final Map<String, int> _lastSequences = {};

  ThingdService._(this._bridge);

  static Future<ThingdService> open() async {
    await RustLib.init();
    final dir = await getApplicationDocumentsDirectory();
    final bridge = await ThingdBridge.open(path: '${dir.path}/thingd.db');
    return ThingdService._(bridge);
  }

  /// Return the last known event sequence for a match, or null if unknown.
  int? getLastSequence(String matchId) => _lastSequences[matchId];

  /// Store the last known event sequence for a match.
  void setLastSequence(String matchId, int sequence) {
    _lastSequences[matchId] = sequence;
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

  /// Save multiple configs in a single transaction.
  Future<void> saveMatchConfigBatch(Map<String, Map<String, dynamic>> configs) async {
    final objects = configs.entries.map((e) => (
      'matches',
      e.key,
      jsonEncode(e.value),
    )).toList();
    await _bridge.putObjectsBatch(objects: objects);
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

  /// Fetch all turns by replaying the full event stream.
  Future<List<TurnMutation>> listTurns(String matchId) async {
    final bodies = await _bridge.listEvents(stream: 'match_$matchId');
    return bodies
        .map((b) => TurnMutation.fromJson(jsonDecode(b) as Map<String, dynamic>))
        .toList();
  }

  /// Fetch only turns after the given sequence number.
  ///
  /// Returns a list of `(TurnMutation, sequence)` pairs.
  /// Pass `fromSequence: 0` to fetch all, `limit: 0` for no limit.
  Future<List<(TurnMutation, int)>> listTurnsFrom(
    String matchId, {
    int fromSequence = 0,
    int limit = 0,
  }) async {
    final results = await _bridge.listEventsFrom(
      stream: 'match_$matchId',
      fromSequence: BigInt.from(fromSequence),
      limit: BigInt.from(limit),
    );
    return results.map((r) {
      final (body, seq) = r;
      final turn = TurnMutation.fromJson(jsonDecode(body) as Map<String, dynamic>);
      return (turn, seq.toInt());
    }).toList();
  }

  Future<void> undoLastTurn(String matchId) async {
    await _bridge.deleteLastEvent(stream: 'match_$matchId');
  }

  Future<void> deleteMatch(String matchId) async {
    await _bridge.deleteStream(stream: 'match_$matchId');
    await _bridge.deleteObject(collection: 'matches', id: matchId);
    _lastSequences.remove(matchId);
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

  // ── Lifecycle ───────────────────────────────────────────────────────

  /// Flush the SQLite WAL into the main database file.
  ///
  /// Call before the app goes to background.
  Future<void> walCheckpoint() async {
    await _bridge.walCheckpoint();
  }

  /// Optimize the FTS5 search index.
  ///
  /// Run periodically (e.g. every 50 turns) to prevent fragmentation.
  Future<void> optimizeSearchIndex() async {
    await _bridge.optimizeSearchIndex();
  }

  // ── Cleanup ─────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    final matchId = await getActiveMatchId();
    if (matchId != null) {
      await deleteMatch(matchId);
    }
    await _bridge.deleteObject(collection: 'active_match', id: 'current');
    _lastSequences.clear();
  }
}
