import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../providers/core_providers.dart';

final tournamentsControllerProvider = Provider<TournamentsController>((ref) => TournamentsController(ref));

class TournamentsController {
  final Ref ref;
  TournamentsController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> create({required String name, required String game, int entryFee = 0, int maxPlayers = 8}) async {
    if (name.trim().isEmpty || maxPlayers < 2 || maxPlayers > 128 || entryFee < 0) throw StateError('راجع اسم البطولة وعدد اللاعبين والاشتراك.');
    await _db.into(_db.tournaments).insert(
          TournamentsCompanion.insert(
            id: const Uuid().v4(),
            name: name,
            game: Value(game),
            entryFee: Value(entryFee),
            maxPlayers: Value(maxPlayers),
          ),
        );
  }

  Future<void> addPlayer(String tournamentId, String playerName, {String team = ''}) => _db.transaction(() async {
    final t = await (_db.select(_db.tournaments)..where((x) => x.id.equals(tournamentId))).getSingle();
    final players = List<Map<String, dynamic>>.from(jsonDecode(t.playersJson) as List);
    if (t.status != 'تسجيل' || players.length >= t.maxPlayers) throw StateError('التسجيل مقفول أو البطولة مكتملة.');
    if (playerName.trim().isEmpty) throw StateError('اكتب اسم اللاعب.');
    players.add({'id': const Uuid().v4(), 'name': playerName.trim(), 'team': team.trim()});
    await (_db.update(_db.tournaments)..where((x) => x.id.equals(tournamentId)))
        .write(TournamentsCompanion(playersJson: Value(jsonEncode(players))));
  });

  Future<void> removePlayer(String tournamentId, String id) => _db.transaction(() async {
    final t = await (_db.select(_db.tournaments)..where((row) => row.id.equals(tournamentId))).getSingle();
    if (t.status != 'تسجيل') throw StateError('التسجيل مقفول.');
    final players = List<Map<String, dynamic>>.from(jsonDecode(t.playersJson) as List)
      ..removeWhere((player) => player['id'] == id);
    await (_db.update(_db.tournaments)..where((row) => row.id.equals(tournamentId)))
        .write(TournamentsCompanion(playersJson: Value(jsonEncode(players))));
  });

  /// توليد البراكت — إقصاء مباشر (single elimination)، مع bye تلقائي لو عدد
  /// اللاعبين مش قوة لـ 2.
  Future<void> startTournament(String tournamentId) => _db.transaction(() async {
    final t = await (_db.select(_db.tournaments)..where((x) => x.id.equals(tournamentId))).getSingle();
    final players = List<Map<String, dynamic>>.from(jsonDecode(t.playersJson) as List);
    if (t.status != 'تسجيل' || players.length < 2) {
      throw StateError('البطولة لازم تكون في التسجيل وفيها لاعبين على الأقل.');
    }

    final shuffled = List<Map<String, dynamic>>.from(players)..shuffle(Random());
    var bracketSize = 1;
    while (bracketSize < shuffled.length) {
      bracketSize *= 2;
    }
    final byes = bracketSize - shuffled.length;
    final firstRound = <Map<String, dynamic>>[];
    var cursor = 0;
    for (var match = 0; match < bracketSize ~/ 2; match++) {
      final p1 = shuffled[cursor++];
      final isBye = match < byes;
      final p2 = isBye ? <String, dynamic>{'id': null, 'name': 'تأهل مباشر'} : shuffled[cursor++];
      firstRound.add({
        'id': '${tournamentId}_r0_m$match',
        'player1': p1,
        'player2': p2,
        'winner': isBye ? (p1['id'] != null ? p1 : p2) : null,
        'is_bye': isBye,
      });
    }

    await (_db.update(_db.tournaments)..where((x) => x.id.equals(tournamentId))).write(
      TournamentsCompanion(
        status: const Value('جارية'),
        roundsJson: Value(jsonEncode([firstRound])),
        currentRound: const Value(0),
      ),
    );
    await _maybeGenerateNextRound(tournamentId);
  });

  Future<void> setMatchScore(String tournamentId, int roundIndex, int matchIndex, int first, int second) =>
      _db.transaction(() async {
    final t = await (_db.select(_db.tournaments)..where((row) => row.id.equals(tournamentId))).getSingle();
    if (t.status != 'جارية' || roundIndex != t.currentRound || first < 0 || second < 0 || first == second) {
      throw StateError('اكتب نتيجة صحيحة فيها فائز.');
    }
    final rounds = List<List<dynamic>>.from(
      (jsonDecode(t.roundsJson) as List).map((round) => List<dynamic>.from(round as List)),
    );
    final match = Map<String, dynamic>.from(rounds[roundIndex][matchIndex] as Map);
    if (match['winner'] != null || match['is_bye'] == true) throw StateError('المباراة اتحسمت بالفعل.');
    match['score1'] = first;
    match['score2'] = second;
    match['winner'] = match[first > second ? 'player1' : 'player2'];
    rounds[roundIndex][matchIndex] = match;
    await (_db.update(_db.tournaments)..where((row) => row.id.equals(tournamentId)))
        .write(TournamentsCompanion(roundsJson: Value(jsonEncode(rounds))));
    await _maybeGenerateNextRound(tournamentId);
  });

  Future<void> _maybeGenerateNextRound(String tournamentId) async {
    final t = await (_db.select(_db.tournaments)..where((x) => x.id.equals(tournamentId))).getSingle();
    final rounds = List<List<dynamic>>.from(
      (jsonDecode(t.roundsJson) as List).map((r) => List<dynamic>.from(r as List)),
    );
    final lastRound = rounds.last.map((m) => Map<String, dynamic>.from(m as Map)).toList();

    final allDecided = lastRound.every((m) => m['winner'] != null);
    if (!allDecided) return;

    if (lastRound.length == 1) {
      final winner = Map<String, dynamic>.from(lastRound.first['winner'] as Map);
      await (_db.update(_db.tournaments)..where((x) => x.id.equals(tournamentId))).write(
        TournamentsCompanion(status: const Value('منتهية'), winnerId: Value(winner['id']?.toString())),
      );
      return;
    }

    final winners = lastRound.map((m) => Map<String, dynamic>.from(m['winner'] as Map)).toList();
    final nextRound = <Map<String, dynamic>>[];
    for (var i = 0; i < winners.length; i += 2) {
      final p1 = winners[i];
      final p2 = i + 1 < winners.length ? winners[i + 1] : {'id': null, 'name': 'BYE'};
      final isBye = p2['id'] == null;
      nextRound.add({
        'id': '${tournamentId}_r${rounds.length}_m${i ~/ 2}',
        'player1': p1,
        'player2': p2,
        'winner': isBye ? p1 : null,
        'is_bye': isBye,
      });
    }
    rounds.add(nextRound);
    await (_db.update(_db.tournaments)..where((x) => x.id.equals(tournamentId))).write(
      TournamentsCompanion(roundsJson: Value(jsonEncode(rounds)), currentRound: Value(rounds.length - 1)),
    );
    await _maybeGenerateNextRound(tournamentId);
  }

  Future<void> delete(String tournamentId) async {
    await (_db.delete(_db.tournaments)..where((x) => x.id.equals(tournamentId))).go();
  }

}
