import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leaderboard_repository/leaderboard_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _legacyStorageKey = 'moovz_dash_leaderboard';
const _difficultyKey = 'medium';
const _storageKey = 'moovz_dash_leaderboard_$_difficultyKey';

LeaderboardEntryData _entry(String nickname, int score) {
  return LeaderboardEntryData(playerNickname: nickname, score: score);
}

List<LeaderboardEntryData> _entriesWithScores(List<int> scores) {
  return [for (final score in scores) _entry('user$score', score)];
}

void main() {
  group('LocalLeaderboardRepository', () {
    late SharedPreferences preferences;
    late LocalLeaderboardRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      repository = LocalLeaderboardRepository(preferences);
    });

    test('implements LeaderboardRepository', () {
      expect(repository, isA<LeaderboardRepository>());
    });

    group('fetchTop10Leaderboard', () {
      test('returns an empty list when nothing was stored', () async {
        final leaderboard = await repository.fetchTop10Leaderboard(
          difficultyKey: _difficultyKey,
        );

        expect(leaderboard, isEmpty);
      });

      test('returns the stored entries in score descending order', () async {
        await repository.addLeaderboardEntry(
          _entry('low', 100),
          difficultyKey: _difficultyKey,
        );
        await repository.addLeaderboardEntry(
          _entry('high', 2500),
          difficultyKey: _difficultyKey,
        );
        await repository.addLeaderboardEntry(
          _entry('mid', 1000),
          difficultyKey: _difficultyKey,
        );

        final leaderboard = await repository.fetchTop10Leaderboard(
          difficultyKey: _difficultyKey,
        );

        expect(
          leaderboard,
          equals([
            _entry('high', 2500),
            _entry('mid', 1000),
            _entry('low', 100),
          ]),
        );
      });

      test(
        'throws FetchTop10LeaderboardException when reading fails',
        () async {
          SharedPreferences.setMockInitialValues({_storageKey: 42});
          final failingPreferences = await SharedPreferences.getInstance();
          final failingRepository = LocalLeaderboardRepository(
            failingPreferences,
          );

          await expectLater(
            failingRepository.fetchTop10Leaderboard(
              difficultyKey: _difficultyKey,
            ),
            throwsA(isA<FetchTop10LeaderboardException>()),
          );
        },
      );

      test('throws LeaderboardDeserializationException when stored json '
          'is corrupted', () async {
        SharedPreferences.setMockInitialValues({_storageKey: 'not json'});
        final corruptedPreferences = await SharedPreferences.getInstance();
        final corruptedRepository = LocalLeaderboardRepository(
          corruptedPreferences,
        );

        await expectLater(
          corruptedRepository.fetchTop10Leaderboard(
            difficultyKey: _difficultyKey,
          ),
          throwsA(isA<LeaderboardDeserializationException>()),
        );
      });

      test('throws LeaderboardDeserializationException when stored entry '
          'is malformed', () async {
        SharedPreferences.setMockInitialValues({
          _storageKey: jsonEncode([
            {'playerNickname': 'ABC'},
          ]),
        });
        final malformedPreferences = await SharedPreferences.getInstance();
        final malformedRepository = LocalLeaderboardRepository(
          malformedPreferences,
        );

        await expectLater(
          malformedRepository.fetchTop10Leaderboard(
            difficultyKey: _difficultyKey,
          ),
          throwsA(isA<LeaderboardDeserializationException>()),
        );
      });
    });

    group('difficulty separation and migration', () {
      test('keeps leaderboards of different difficulties apart', () async {
        await repository.addLeaderboardEntry(
          _entry('easy', 100),
          difficultyKey: 'easy',
        );

        expect(
          await repository.fetchTop10Leaderboard(difficultyKey: 'hard'),
          isEmpty,
        );
        expect(
          await repository.fetchTop10Leaderboard(difficultyKey: 'easy'),
          equals([_entry('easy', 100)]),
        );
      });

      test('migrates the legacy leaderboard to medium', () async {
        SharedPreferences.setMockInitialValues({
          _legacyStorageKey: jsonEncode([
            {'playerNickname': 'old', 'score': 900},
          ]),
        });
        final legacyPreferences = await SharedPreferences.getInstance();
        final legacyRepository = LocalLeaderboardRepository(legacyPreferences);

        expect(
          await legacyRepository.fetchTop10Leaderboard(difficultyKey: 'medium'),
          equals([_entry('old', 900)]),
        );
        expect(legacyPreferences.getString(_storageKey), isNotNull);
        expect(
          await legacyRepository.fetchTop10Leaderboard(difficultyKey: 'easy'),
          isEmpty,
        );
      });
    });

    group('addLeaderboardEntry', () {
      test('saves the entry as json under the storage key', () async {
        await repository.addLeaderboardEntry(
          _entry('ABC', 1500),
          difficultyKey: _difficultyKey,
        );

        final storedValue = preferences.getString(_storageKey);

        expect(
          storedValue,
          equals(
            jsonEncode([
              {'playerNickname': 'ABC', 'score': 1500},
            ]),
          ),
        );
      });

      test('keeps at most 10 entries', () async {
        final scores = [for (var score = 1; score <= 12; score++) score * 100];
        for (final entry in _entriesWithScores(scores)) {
          await repository.addLeaderboardEntry(
            entry,
            difficultyKey: _difficultyKey,
          );
        }

        final leaderboard = await repository.fetchTop10Leaderboard(
          difficultyKey: _difficultyKey,
        );

        expect(leaderboard, hasLength(10));
        expect(leaderboard.first.score, equals(1200));
        expect(leaderboard.last.score, equals(300));
      });

      test(
        'discards entries below the top 10 when the leaderboard is full',
        () async {
          final fullLeaderboard = _entriesWithScores([
            10000,
            9500,
            9000,
            8500,
            8000,
            7500,
            7000,
            6500,
            6000,
            5500,
          ]);
          for (final entry in fullLeaderboard) {
            await repository.addLeaderboardEntry(
              entry,
              difficultyKey: _difficultyKey,
            );
          }

          await repository.addLeaderboardEntry(
            _entry('late', 5000),
            difficultyKey: _difficultyKey,
          );

          final leaderboard = await repository.fetchTop10Leaderboard(
            difficultyKey: _difficultyKey,
          );

          expect(leaderboard, equals(fullLeaderboard));
        },
      );

      test(
        'inserts a higher entry and drops the lowest of a full leaderboard',
        () async {
          final fullLeaderboard = _entriesWithScores([
            10000,
            9500,
            9000,
            8500,
            8000,
            7500,
            7000,
            6500,
            6000,
            5500,
          ]);
          for (final entry in fullLeaderboard) {
            await repository.addLeaderboardEntry(
              entry,
              difficultyKey: _difficultyKey,
            );
          }

          final newEntry = _entry('ABC', 15000);
          await repository.addLeaderboardEntry(
            newEntry,
            difficultyKey: _difficultyKey,
          );

          final leaderboard = await repository.fetchTop10Leaderboard(
            difficultyKey: _difficultyKey,
          );

          expect(leaderboard, hasLength(10));
          expect(leaderboard.first, equals(newEntry));
          expect(
            leaderboard.map((entry) => entry.score),
            isNot(contains(5500)),
          );
        },
      );

      test('keeps the oldest entry first when scores are tied', () async {
        await repository.addLeaderboardEntry(
          _entry('first', 800),
          difficultyKey: _difficultyKey,
        );
        await repository.addLeaderboardEntry(
          _entry('second', 800),
          difficultyKey: _difficultyKey,
        );
        await repository.addLeaderboardEntry(
          _entry('third', 900),
          difficultyKey: _difficultyKey,
        );

        final leaderboard = await repository.fetchTop10Leaderboard(
          difficultyKey: _difficultyKey,
        );

        expect(
          leaderboard,
          equals([
            _entry('third', 900),
            _entry('first', 800),
            _entry('second', 800),
          ]),
        );
      });

      test('does not save a tied entry when the leaderboard is full '
          'and its score equals the lowest top 10 score', () async {
        final fullLeaderboard = _entriesWithScores([
          10000,
          9500,
          9000,
          8500,
          8000,
          7500,
          7000,
          6500,
          6000,
          5500,
        ]);
        for (final entry in fullLeaderboard) {
          await repository.addLeaderboardEntry(
            entry,
            difficultyKey: _difficultyKey,
          );
        }

        await repository.addLeaderboardEntry(
          _entry('tied', 5500),
          difficultyKey: _difficultyKey,
        );

        final leaderboard = await repository.fetchTop10Leaderboard(
          difficultyKey: _difficultyKey,
        );

        expect(leaderboard, equals(fullLeaderboard));
      });

      test('throws AddLeaderboardEntryException when writing fails', () async {
        final failingRepository = LocalLeaderboardRepository(
          _ThrowingSharedPreferences(),
        );

        await expectLater(
          failingRepository.addLeaderboardEntry(
            _entry('ABC', 1500),
            difficultyKey: _difficultyKey,
          ),
          throwsA(isA<AddLeaderboardEntryException>()),
        );
      });

      test('throws AddLeaderboardEntryException when SharedPreferences '
          'reports the write was not saved', () async {
        final rejectingRepository = LocalLeaderboardRepository(
          _RejectingSharedPreferences(),
        );

        await expectLater(
          rejectingRepository.addLeaderboardEntry(
            _entry('ABC', 1500),
            difficultyKey: _difficultyKey,
          ),
          throwsA(isA<AddLeaderboardEntryException>()),
        );
      });

      test('persists entries across repository instances', () async {
        await repository.addLeaderboardEntry(
          _entry('ABC', 1500),
          difficultyKey: _difficultyKey,
        );

        final reopenedPreferences = await SharedPreferences.getInstance();
        final reopenedRepository = LocalLeaderboardRepository(
          reopenedPreferences,
        );

        expect(
          await reopenedRepository.fetchTop10Leaderboard(
            difficultyKey: _difficultyKey,
          ),
          equals([_entry('ABC', 1500)]),
        );
      });
    });
  });
}

class _ThrowingSharedPreferences extends Fake implements SharedPreferences {
  @override
  String? getString(String key) => null;

  @override
  Future<bool> setString(String key, String value) {
    throw Exception('disk full');
  }
}

class _RejectingSharedPreferences extends Fake implements SharedPreferences {
  @override
  String? getString(String key) => null;

  @override
  Future<bool> setString(String key, String value) async => false;
}
