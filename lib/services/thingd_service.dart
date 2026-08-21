import 'dart:convert';

import 'package:path_provider/path_provider.dart';

import '../data/models/detection_log.dart';
import '../data/models/player_profile.dart';
import '../data/models/turn_mutation.dart';
import '../src/rust/api/bridge.dart';
import '../src/rust/frb_generated.dart';
import 'thingd_service_interface.dart';

class ThingdService implements ThingdServiceInterface {
  final ThingdBridge _bridge;

  /// Public access to the underlying bridge (needed by CloudAuthService).
  ThingdBridge get bridge => _bridge;

  /// Cached last-known event sequence per match stream for incremental replay.
  final Map<String, int> _lastSequences = {};

  ThingdService._(this._bridge);

  static Future<ThingdService> open() async {
    await RustLib.init();
    final dir = await getApplicationDocumentsDirectory();
    // Thingd 0.83.2 uses a RocksDB-backed directory. Keep this path distinct
    // from the retired SQLite file because this release intentionally starts
    // with a fresh local store.
    final bridge = await ThingdBridge.open(path: '${dir.path}/thingd-rocksdb');
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

  Future<void> completeMatch(
    String matchId, {
    required String winnerPlayerId,
    required int totalTurns,
  }) async {
    final config = await getMatchConfig(matchId);
    if (config == null) return;
    config['completedAt'] = DateTime.now().toIso8601String();
    config['winnerPlayerId'] = winnerPlayerId;
    config['totalTurns'] = totalTurns;
    await _bridge.putObject(
      collection: 'matches',
      id: matchId,
      body: jsonEncode(config),
    );
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

  // ── Detection logs (EventLog) ──────────────────────────────────────

  Future<void> appendDetectionLog(
    String matchId,
    DetectionLog log,
  ) async {
    final body = jsonEncode(log.toJson());
    await _bridge.appendEvent(
      stream: '${matchId}_detect',
      eventType: 'detection.result',
      body: body,
    );
  }

  // ── Player Profiles (ObjectStore) ────────────────────────────────────

  Future<void> savePlayerProfile(PlayerProfile profile) async {
    await _bridge.putObject(
      collection: 'players',
      id: profile.id,
      body: jsonEncode(profile.toJson()),
    );
  }

  Future<PlayerProfile?> getPlayerProfile(String id) async {
    final body = await _bridge.getObject(collection: 'players', id: id);
    if (body == null) return null;
    return PlayerProfile.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  /// Fetch all known player profiles.
  Future<List<PlayerProfile>> listPlayerProfiles() async {
    final objects = await _bridge.listObjects(
      collection: 'players',
      limit: BigInt.from(100),
      offset: BigInt.zero,
    );
    return objects.map((pair) {
      final (_, body) = pair;
      return PlayerProfile.fromJson(jsonDecode(body) as Map<String, dynamic>);
    }).toList();
  }

  // ── User Email (ObjectStore) ─────────────────────────────────────────

  /// Save the user's email for cloud scoping.
  Future<void> saveUserEmail(String email) async {
    await _bridge.putObject(
      collection: 'config',
      id: 'cloud_user',
      body: jsonEncode({'email': email, 'savedAt': DateTime.now().toIso8601String()}),
    );
  }

  /// Load the user's saved email. Returns null if not set.
  Future<String?> getUserEmail() async {
    final body = await _bridge.getObject(collection: 'config', id: 'cloud_user');
    if (body == null) return null;
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['email'] as String?;
  }

  // ── Search (Searcher) ───────────────────────────────────────────────

  /// Full-text search across match history.
  Future<List<Map<String, dynamic>>> searchMatches(
    String query, {
    int limit = 20,
  }) async {
    final hits = await _bridge.search(
      query: query,
      collection: 'match_history',
      limit: BigInt.from(limit),
    );
    return hits.map((h) => jsonDecode(h) as Map<String, dynamic>).toList();
  }

  // ── Aggregation (AggregateStore) ────────────────────────────────────

  /// Run an aggregation over a collection.
  /// [params] is a JSON string with function, field, groupBy.
  Future<Map<String, dynamic>> aggregate(
    String collection,
    String params,
  ) async {
    final result = await _bridge.aggregate(
      collection: collection,
      params: params,
    );
    return jsonDecode(result) as Map<String, dynamic>;
  }

  // ── Queue (QueueStore) ──────────────────────────────────────────────

  /// Push a CV processing job to the background queue.
  Future<String> enqueueCVTask(
    String imagePath,
    String matchId, {
    int maxAttempts = 3,
  }) async {
    return await _bridge.pushJob(
      queue: 'vision',
      jobId: '',
      body: jsonEncode({'imagePath': imagePath, 'matchId': matchId}),
      maxAttempts: maxAttempts,
    );
  }

  /// Claim a vision task job.
  Future<Map<String, dynamic>?> claimCVTask({int leaseMs = 30000}) async {
    final result = await _bridge.claimJob(
      queue: 'vision',
      leaseMs: BigInt.from(leaseMs),
    );
    if (result.isEmpty) return null;
    return jsonDecode(result) as Map<String, dynamic>;
  }

  /// Acknowledge a vision task.
  Future<bool> ackCVTask(String jobId) async {
    return await _bridge.ackJob(queue: 'vision', jobId: jobId);
  }

  /// Reject a vision task for retry.
  Future<bool> nackCVTask(String jobId, {int delayMs = 5000, String error = ''}) async {
    return await _bridge.nackJob(
      queue: 'vision',
      jobId: jobId,
      delayMs: BigInt.from(delayMs),
      error: error,
    );
  }

  // ── Graph Links (LinkStore) ─────────────────────────────────────────

  /// Link a player to a match.
  Future<void> linkPlayerToMatch(String playerId, String matchId) async {
    await _bridge.createLink(
      fromRef: 'player_$playerId',
      linkType: 'played',
      toRef: 'match_$matchId',
    );
  }

  /// Get all matches a player has played.
  Future<List<String>> getPlayerMatchIds(String playerId) async {
    final links = await _bridge.getNeighbors(
      reference: 'player_$playerId',
      direction: 'Outgoing',
      linkType: 'played',
    );
    return links.map((l) {
      final json = jsonDecode(l) as Map<String, dynamic>;
      return (json['toRef'] as String).replaceFirst('match_', '');
    }).toList();
  }

  // ── Lifecycle ───────────────────────────────────────────────────────

  /// Flush the SQLite WAL into the main database file.
  Future<void> walCheckpoint() async {
    await _bridge.walCheckpoint();
  }

  /// Optimize the FTS5 search index.
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
