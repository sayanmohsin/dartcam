import 'package:flutter_test/flutter_test.dart';
import 'package:local_dart_scorer/core/vision/dartboard_scorer.dart';
import 'package:local_dart_scorer/data/models/match_state.dart';
import 'package:local_dart_scorer/data/state/match_state_manager.dart';
import 'fakes/fake_thingd_service.dart';

void main() {
  group('MatchStateManager.create', () {
    test('creates match with correct initial state', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice', 'Bob'],
        gameType: 501,
      );

      expect(manager.value.gameType, 501);
      expect(manager.value.players.length, 2);
      expect(manager.value.players[0].name, 'Alice');
      expect(manager.value.players[1].name, 'Bob');
      expect(manager.value.players[0].currentScore, 501);
      expect(manager.value.history, isEmpty);
      expect(manager.value.status, MatchStatus.active);
      expect(manager.value.activePlayerIndex, 0);
    });

    test('saveMatchConfig and setActiveMatchId are called', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice'],
        gameType: 301,
      );

      final config = await fake.getMatchConfig(manager.matchId);
      expect(config, isNotNull);
      expect(config!['gameType'], 301);
      expect(config['playerNames'], ['Alice']);

      final activeId = await fake.getActiveMatchId();
      expect(activeId, manager.matchId);
    });
  });

  group('MatchStateManager.recordTurn', () {
    test('deducts score from active player', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice', 'Bob'],
        gameType: 501,
      );

      await manager.recordTurn([60, 60, 60]);

      expect(manager.value.players[0].currentScore, 501 - 180);
      expect(manager.value.history.length, 1);
      expect(manager.value.history[0].totalTurnScore, 180);
    });

    test('advances to next player after turn', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice', 'Bob'],
        gameType: 501,
      );

      expect(manager.value.activePlayerIndex, 0);
      expect(manager.value.activePlayer.name, 'Alice');

      await manager.recordTurn([20]);

      expect(manager.value.activePlayerIndex, 1);
      expect(manager.value.activePlayer.name, 'Bob');
    });

    test('returns overBust when score goes below 0', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice'],
        gameType: 10,
      );

      final result = await manager.recordTurn([20]);
      expect(result, BustResult.overBust);
      expect(manager.value.players[0].currentScore, 10);
    });

    test('returns oneBust when score becomes 1', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice'],
        gameType: 3,
      );

      final result = await manager.recordTurn([2]);
      expect(result, BustResult.oneBust);
    });

    test('returns notDouble when checkout is not on a double', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice'],
        gameType: 40,
      );

      // Finish with single 20 (not a double) — should bust
      final result = await manager.recordTurn(
        [40],
        darts: [const ScoredDart(score: 20, multiplier: 1, label: '20')],
      );
      expect(result, BustResult.notDouble);
    });

    test('completes match on legal double checkout', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice'],
        gameType: 40,
      );

      await manager.recordTurn(
        [40],
        darts: [const ScoredDart(score: 20, multiplier: 2, label: 'D20')],
      );

      expect(manager.value.status, MatchStatus.completed);
      expect(manager.value.players[0].currentScore, 0);
    });

    test('tracks 180 stats', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice'],
        gameType: 501,
      );

      await manager.recordTurn(
        [60, 60, 60],
        darts: const [
          ScoredDart(score: 20, multiplier: 3, label: 'T20'),
          ScoredDart(score: 20, multiplier: 3, label: 'T20'),
          ScoredDart(score: 20, multiplier: 3, label: 'T20'),
        ],
      );

      final remaining = manager.value.players[0].currentScore;
      await manager.recordTurn(
        [remaining],
        darts: [ScoredDart(score: remaining ~/ 2, multiplier: 2, label: 'D${remaining ~/ 2}')],
      );

      final profile = await fake.getPlayerProfile(manager.value.players[0].id);
      expect(profile, isNotNull);
      expect(profile!.oneEightyCount, 1);
    });

    test('persists player profiles on match completion', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice'],
        gameType: 40,
      );

      await manager.recordTurn(
        [40],
        darts: [const ScoredDart(score: 20, multiplier: 2, label: 'D20')],
      );

      final profile = await fake.getPlayerProfile(manager.value.players[0].id);
      expect(profile, isNotNull);
      expect(profile!.totalMatches, 1);
      expect(profile.totalWins, 1);
    });

    test('appends turn event to thingd', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice', 'Bob'],
        gameType: 501,
      );

      await manager.recordTurn([60]);

      final turns = await fake.listTurns(manager.matchId);
      expect(turns.length, 1);
      expect(turns[0].totalTurnScore, 60);
      expect(turns[0].playerId, manager.value.players[0].id);
    });
  });

  group('MatchStateManager.undoLastTurn', () {
    test('restores previous score and history', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice', 'Bob'],
        gameType: 501,
      );

      await manager.recordTurn([60]);
      expect(manager.value.history.length, 1);

      await manager.undoLastTurn();
      expect(manager.value.history, isEmpty);
      expect(manager.value.players[0].currentScore, 501);
    });

    test('does nothing when history is empty', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice'],
        gameType: 501,
      );

      await manager.undoLastTurn();
      expect(manager.value.players[0].currentScore, 501);
    });
  });

  group('MatchStateManager.load', () {
    test('returns null when no active match', () async {
      final fake = FakeThingdService();
      final loaded = await MatchStateManager.load(fake as dynamic);
      expect(loaded, isNull);
    });

    test('recreates state from event stream', () async {
      final fake = FakeThingdService();
      var manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice', 'Bob'],
        gameType: 501,
      );

      await manager.recordTurn([60]);
      await manager.recordTurn([40]);

      final loaded = await MatchStateManager.load(fake as dynamic);
      expect(loaded, isNotNull);
      expect(loaded!.value.players[0].currentScore, 501 - 60);
      expect(loaded.value.players[1].currentScore, 501 - 40);
      expect(loaded.value.history.length, 2);
    });
  });

  group('MatchStateManager.resetMatch', () {
    test('clears history and creates new matchId', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice'],
        gameType: 501,
      );

      final oldId = manager.matchId;
      await manager.recordTurn([60]);
      await manager.resetMatch();

      expect(manager.matchId, isNot(oldId));
      expect(manager.value.history, isEmpty);
      expect(manager.value.players[0].currentScore, 501);
    });
  });

  group('MatchStateManager.endMatch', () {
    test('clears active match and deletes data', () async {
      final fake = FakeThingdService();
      final manager = await MatchStateManager.create(
        thingd: fake as dynamic,
        playerNames: ['Alice'],
        gameType: 501,
      );

      await manager.endMatch();
      final activeId = await fake.getActiveMatchId();
      expect(activeId, isNull);
    });
  });
}
