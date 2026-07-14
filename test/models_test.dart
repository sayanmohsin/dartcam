import 'package:flutter_test/flutter_test.dart';
import 'package:local_dart_scorer/data/models/player_profile.dart';
import 'package:local_dart_scorer/data/models/turn_mutation.dart';
import 'package:local_dart_scorer/data/models/match_state.dart';
import 'package:local_dart_scorer/data/models/detection_log.dart';

void main() {
  group('PlayerProfile', () {
    test('toJson/fromJson round-trip', () {
      const original = PlayerProfile(
        id: 'player-1',
        name: 'Alice',
        currentScore: 301,
      );

      final json = original.toJson();
      final restored = PlayerProfile.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.currentScore, original.currentScore);
    });

    test('copyWith preserves unchanged fields', () {
      const original = PlayerProfile(
        id: 'player-1',
        name: 'Alice',
        currentScore: 301,
      );

      final updated = original.copyWith(currentScore: 250);

      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.currentScore, 250);
    });

    test('copyWith with no args returns identical copy', () {
      const original = PlayerProfile(
        id: 'player-1',
        name: 'Alice',
        currentScore: 301,
      );

      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.currentScore, original.currentScore);
    });
  });

  group('TurnMutation', () {
    test('toJson/fromJson round-trip', () {
      const original = TurnMutation(
        playerId: 'player-1',
        detectedScores: [20, 20, 20],
        totalTurnScore: 60,
        scoreBeforeTurn: 301,
      );

      final json = original.toJson();
      final restored = TurnMutation.fromJson(json);

      expect(restored.playerId, original.playerId);
      expect(restored.detectedScores, original.detectedScores);
      expect(restored.totalTurnScore, original.totalTurnScore);
      expect(restored.scoreBeforeTurn, original.scoreBeforeTurn);
    });

    test('handles empty detectedScores list', () {
      const original = TurnMutation(
        playerId: 'player-1',
        detectedScores: [],
        totalTurnScore: 0,
        scoreBeforeTurn: 301,
      );

      final json = original.toJson();
      final restored = TurnMutation.fromJson(json);

      expect(restored.detectedScores, isEmpty);
      expect(restored.totalTurnScore, 0);
    });

    test('round-trips dartLabels and dartMultipliers', () {
      const original = TurnMutation(
        playerId: 'player-1',
        detectedScores: [60, 45, 20],
        totalTurnScore: 125,
        scoreBeforeTurn: 301,
        dartLabels: ['T20', 'D15', 'D10'],
        dartMultipliers: [3, 2, 2],
        isAutoDetected: true,
      );

      final json = original.toJson();
      final restored = TurnMutation.fromJson(json);

      expect(restored.dartLabels, ['T20', 'D15', 'D10']);
      expect(restored.dartMultipliers, [3, 2, 2]);
      expect(restored.isAutoDetected, isTrue);
    });

    test('defaults isAutoDetected to false when missing from JSON', () {
      final json = {
        'playerId': 'player-1',
        'detectedScores': [20],
        'totalTurnScore': 20,
        'scoreBeforeTurn': 301,
      };

      final restored = TurnMutation.fromJson(json);
      expect(restored.isAutoDetected, isFalse);
      expect(restored.dartLabels, isNull);
    });
  });

  group('DetectionLog', () {
    test('toJson/fromJson round-trip', () {
      final original = DetectionLog(
        timestamp: DateTime(2025, 6, 15, 14, 30, 0),
        imagePath: '/tmp/shot.png',
        imageSizeBytes: 2457600,
        rawBoxCount: 2500,
        nmsBoxCount: 2190,
        classDistribution: {0: 2190},
        dartTipCount: 3,
        calibrationPointIds: [1, 2],
        status: 'board_not_detected',
        confidenceThreshold: 0.25,
      );

      final json = original.toJson();
      final restored = DetectionLog.fromJson(json);

      expect(restored.timestamp, original.timestamp);
      expect(restored.imagePath, '/tmp/shot.png');
      expect(restored.imageSizeBytes, 2457600);
      expect(restored.rawBoxCount, 2500);
      expect(restored.nmsBoxCount, 2190);
      expect(restored.classDistribution, {0: 2190});
      expect(restored.dartTipCount, 3);
      expect(restored.calibrationPointIds, [1, 2]);
      expect(restored.status, 'board_not_detected');
      expect(restored.confidenceThreshold, 0.25);
    });

    test('handles null image fields', () {
      final original = DetectionLog(
        timestamp: DateTime(2025, 6, 15),
        rawBoxCount: 0,
        nmsBoxCount: 0,
        classDistribution: {},
        dartTipCount: 0,
        calibrationPointIds: [],
        status: 'detection_failed',
        confidenceThreshold: 0.25,
      );

      final json = original.toJson();
      final restored = DetectionLog.fromJson(json);

      expect(restored.imagePath, isNull);
      expect(restored.imageSizeBytes, isNull);
      expect(restored.calibrationPointIds, isEmpty);
    });
  });

  group('DartMatchState', () {
    test('toJson/fromJson round-trip', () {
      final original = DartMatchState(
        gameType: 501,
        activePlayerIndex: 0,
        players: const [
          PlayerProfile(id: 'p1', name: 'Alice', currentScore: 301),
          PlayerProfile(id: 'p2', name: 'Bob', currentScore: 250),
        ],
        history: const [
          TurnMutation(
            playerId: 'p1',
            detectedScores: [20, 20, 20],
            totalTurnScore: 60,
            scoreBeforeTurn: 301,
          ),
        ],
        status: MatchStatus.active,
      );

      final json = original.toJson();
      final restored = DartMatchState.fromJson(json);

      expect(restored.gameType, 501);
      expect(restored.activePlayerIndex, 0);
      expect(restored.players.length, 2);
      expect(restored.players[0].name, 'Alice');
      expect(restored.players[1].name, 'Bob');
      expect(restored.history.length, 1);
      expect(restored.history[0].totalTurnScore, 60);
      expect(restored.status, MatchStatus.active);
    });

    test('activePlayer returns correct player', () {
      final state = DartMatchState(
        gameType: 501,
        activePlayerIndex: 1,
        players: const [
          PlayerProfile(id: 'p1', name: 'Alice', currentScore: 301),
          PlayerProfile(id: 'p2', name: 'Bob', currentScore: 250),
        ],
        history: const [],
        status: MatchStatus.active,
      );

      expect(state.activePlayer.name, 'Bob');
    });

    test('isCompleted is true when status is completed', () {
      final state = DartMatchState(
        gameType: 501,
        activePlayerIndex: 0,
        players: const [
          PlayerProfile(id: 'p1', name: 'Alice', currentScore: 0),
        ],
        history: const [],
        status: MatchStatus.completed,
      );

      expect(state.isCompleted, isTrue);
    });

    test('isCompleted is false when status is active', () {
      final state = DartMatchState(
        gameType: 501,
        activePlayerIndex: 0,
        players: const [
          PlayerProfile(id: 'p1', name: 'Alice', currentScore: 100),
        ],
        history: const [],
        status: MatchStatus.active,
      );

      expect(state.isCompleted, isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      final original = DartMatchState(
        gameType: 501,
        activePlayerIndex: 0,
        players: const [
          PlayerProfile(id: 'p1', name: 'Alice', currentScore: 301),
        ],
        history: const [],
        status: MatchStatus.active,
      );

      final updated = original.copyWith(
        activePlayerIndex: 1,
        status: MatchStatus.completed,
      );

      expect(updated.gameType, 501);
      expect(updated.activePlayerIndex, 1);
      expect(updated.players, original.players);
      expect(updated.history, original.history);
      expect(updated.status, MatchStatus.completed);
    });

    test('serializes and deserializes with empty history', () {
      final original = DartMatchState(
        gameType: 301,
        activePlayerIndex: 0,
        players: const [
          PlayerProfile(id: 'p1', name: 'Alice', currentScore: 301),
        ],
        history: const [],
        status: MatchStatus.active,
      );

      final json = original.toJson();
      final restored = DartMatchState.fromJson(json);

      expect(restored.history, isEmpty);
      expect(restored.gameType, 301);
    });
  });
}
