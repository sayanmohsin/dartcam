/// Pure Dart benchmark — simulates old (JSON blob) vs new (event-sourced)
/// serialization overhead. No device or thingd needed, runs on VM.
///
/// Run: dart run tool/benchmark_serialization.dart

import 'dart:convert';

// ── Models (inlined to avoid import issues) ───────────────────────

class TurnMutation {
  final String playerId;
  final List<int> detectedScores;
  final int totalTurnScore;
  final int scoreBeforeTurn;

  TurnMutation({
    required this.playerId,
    required this.detectedScores,
    required this.totalTurnScore,
    required this.scoreBeforeTurn,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'detectedScores': detectedScores,
        'totalTurnScore': totalTurnScore,
        'scoreBeforeTurn': scoreBeforeTurn,
      };

  factory TurnMutation.fromJson(Map<String, dynamic> json) => TurnMutation(
        playerId: json['playerId'] as String,
        detectedScores: List<int>.from(json['detectedScores'] as List),
        totalTurnScore: json['totalTurnScore'] as int,
        scoreBeforeTurn: json['scoreBeforeTurn'] as int,
      );
}

// ── Helpers ────────────────────────────────────────────────────────

TurnMutation makeTurn(int index, String pid, int scoreBefore) {
  final dartCount = 1 + (index % 3);
  final scores = List.generate(dartCount, (i) => ((index * 7 + i * 13) % 60) + 1);
  final total = scores.fold(0, (s, v) => s + v);
  return TurnMutation(
    playerId: pid,
    detectedScores: scores,
    totalTurnScore: total,
    scoreBeforeTurn: scoreBefore,
  );
}

// ── OLD: shared_preferences (JSON blob) ────────────────────────────

class OldApproach {
  List<Map<String, dynamic>> _history = [];
  String _blob = '';

  /// Save turn: serialize ENTIRE history as one JSON blob.
  void recordTurn(TurnMutation turn) {
    _history.add(turn.toJson());
    _blob = jsonEncode({'history': _history});
  }

  /// Load: deserialize entire blob.
  List<TurnMutation> load() {
    final decoded = jsonDecode(_blob) as Map<String, dynamic>;
    return (decoded['history'] as List)
        .map((h) => TurnMutation.fromJson(h as Map<String, dynamic>))
        .toList();
  }

  /// Undo: deserialize, pop, re-serialize.
  void undoLastTurn() {
    final turns = load();
    turns.removeLast();
    _history = turns.map((t) => t.toJson()).toList();
    _blob = jsonEncode({'history': _history});
  }

  int get blobSize => utf8.encode(_blob).length;
  int get turnCount => _history.length;
}

// ── NEW: thingd (event-sourced) ────────────────────────────────────

class NewApproach {
  final List<String> _events = [];

  /// Append: serialize ONE turn only.
  void recordTurn(TurnMutation turn) {
    _events.add(jsonEncode(turn.toJson()));
  }

  /// List events: each is already stored individually.
  List<TurnMutation> listEvents() {
    return _events
        .map((e) => TurnMutation.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  /// Undo: delete last event (just remove from list).
  void deleteLastEvent() {
    if (_events.isNotEmpty) _events.removeLast();
  }

  int get totalEventSize => _events.fold(0, (sum, e) => sum + utf8.encode(e).length);
  int get eventCount => _events.length;
}

// ── Benchmark runner ───────────────────────────────────────────────

void bench(String label, void Function() setup, void Function() fn, {int runs = 1000}) {
  // Warm up
  for (int i = 0; i < 100; i++) {
    setup();
    fn();
  }

  final sw = Stopwatch()..start();
  for (int i = 0; i < runs; i++) {
    setup();
    fn();
  }
  sw.stop();
  final avgUs = sw.elapsedMicroseconds / runs;
  print('  $label  avg=${avgUs.toStringAsFixed(1)}µs  ($runs runs in ${sw.elapsedMilliseconds}ms)');
}

void main() {
  final pid1 = 'player-a-uuid-0000';
  final pid2 = 'player-b-uuid-0000';

  print('═══════════════════════════════════════════════════════════════');
  print('  DartCam Persistence Benchmark: OLD (JSON blob) vs NEW (event-sourced)');
  print('═══════════════════════════════════════════════════════════════\n');

  for (final turnCount in [10, 50, 100, 200]) {
    print('─── $turnCount turns ──────────────────────────────────────────');

    // ── Record Turn (measures: re-serialize entire blob vs append 1 event) ──

    {
      OldApproach? old;
      bench('OLD recordTurn (re-serialize all $turnCount)',
          () { old = OldApproach(); for (int i = 0; i < turnCount; i++) { old!.recordTurn(makeTurn(i, i.isEven ? pid1 : pid2, 300)); } },
          () { old!.recordTurn(makeTurn(turnCount, pid1, 200)); });
    }

    {
      NewApproach? nw;
      bench('NEW recordTurn (append 1 event)',
          () { nw = NewApproach(); for (int i = 0; i < turnCount; i++) { nw!.recordTurn(makeTurn(i, i.isEven ? pid1 : pid2, 300)); } },
          () { nw!.recordTurn(makeTurn(turnCount, pid1, 200)); });
    }

    // ── Load / Replay ─────────────────────────────────────

    {
      OldApproach? old;
      bench('OLD load (deserialize $turnCount turns)',
          () { old = OldApproach(); for (int i = 0; i < turnCount; i++) { old!.recordTurn(makeTurn(i, i.isEven ? pid1 : pid2, 300)); } },
          () { old!.load(); });
    }

    {
      NewApproach? nw;
      bench('NEW listEvents (parse $turnCount events)',
          () { nw = NewApproach(); for (int i = 0; i < turnCount; i++) { nw!.recordTurn(makeTurn(i, i.isEven ? pid1 : pid2, 300)); } },
          () { nw!.listEvents(); });
    }

    // ── Undo ──────────────────────────────────────────────

    {
      OldApproach? old;
      bench('OLD undo (load + pop + resave $turnCount)',
          () { old = OldApproach(); for (int i = 0; i < turnCount; i++) { old!.recordTurn(makeTurn(i, i.isEven ? pid1 : pid2, 300)); } },
          () { old!.undoLastTurn(); });
    }

    {
      NewApproach? nw;
      bench('NEW undo (delete last event)',
          () { nw = NewApproach(); for (int i = 0; i < turnCount; i++) { nw!.recordTurn(makeTurn(i, i.isEven ? pid1 : pid2, 300)); } },
          () { nw!.deleteLastEvent(); });
    }

    // ── Storage size ──────────────────────────────────────

    {
      final old = OldApproach();
      final nw = NewApproach();
      for (int i = 0; i < turnCount; i++) {
        final turn = makeTurn(i, i.isEven ? pid1 : pid2, 300);
        old.recordTurn(turn);
        nw.recordTurn(turn);
      }
      final configSize = utf8.encode(jsonEncode({
        'gameType': 501,
        'playerNames': ['Alice', 'Bob'],
      })).length;

      print('  OLD blob size:     ${old.blobSize} bytes');
      print('  NEW events size:  ${nw.totalEventSize} bytes + ${configSize}B config = ${nw.totalEventSize + configSize} bytes');
      print('  NEW is ${((nw.totalEventSize + configSize) / old.blobSize * 100).toStringAsFixed(1)}% of OLD size');
    }

    print('');
  }

  print('═══════════════════════════════════════════════════════════════');
  print('  Note: These measure pure Dart serialization overhead only.');
  print('  On-device benchmarks also include SharedPreferences I/O');
  print('  (write-through to disk on every turn) vs SQLite WAL append');
  print('  (single INSERT per event, batch read on load).');
  print('═══════════════════════════════════════════════════════════════');
}
