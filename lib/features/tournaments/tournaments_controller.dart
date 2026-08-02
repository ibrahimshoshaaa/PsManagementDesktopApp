import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/remote/firebase_service.dart';
import '../../providers/core_providers.dart';

final tournamentsControllerProvider = Provider<TournamentsController>((ref) => TournamentsController(ref));

class TournamentsController {
  final Ref ref;
  TournamentsController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);

  /// البطولات on-demand (زي الموبايل بالظبط) — بنسحبها بس لما حد يفتح الشاشة.
  Future<void> refreshFromRemote() async {
    final shopId = FirebaseService.currentShopId;
    if (shopId == null) return;
    final remote = await FirebaseService.fetchTournamentsOnDemand(shopId);
    for (final t in remote) {
      final id = t['id']?.toString();
      if (id == null) continue;
      await _db.into(_db.tournaments).insertOnConflictUpdate(
            TournamentsCompanion.insert(
              id: id,
              name: t['name']?.toString() ?? '',
              game: Value(t['game']?.toString() ?? ''),
              entryFee: Value((t['entry_fee'] as num?)?.toInt() ?? 0),
              maxPlayers: Value((t['max_players'] as num?)?.toInt() ?? 8),
              status: Value(t['status']?.toString() ?? 'تسجيل'),
              playersJson: Value(jsonEncode(t['players'] ?? [])),
              roundsJson: Value(jsonEncode(t['rounds'] ?? [])),
              currentRound: Value((t['current_round'] as num?)?.toInt() ?? 0),
              winnerId: Value(t['winner_id']?.toString()),
            ),
          );
    }
  }

  Future<void> create({required String name, required String game, int entryFee = 0, int maxPlayers = 8}) async {
    await _db.into(_db.tournaments).insert(
          TournamentsCompanion.insert(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            game: Value(game),
            entryFee: Value(entryFee),
            maxPlayers: Value(maxPlayers),
          ),
        );
    await _pushAll();
  }

  Future<void> addPlayer(String tournamentId, String playerName) async {
    final t = await (_db.select(_db.tournaments)..where((x) => x.id.equals(tournamentId))).getSingle();
    final players = List<Map<String, dynamic>>.from(jsonDecode(t.playersJson) as List);
    players.add({'id': DateTime.now().millisecondsSinceEpoch.toString(), 'name': playerName});
    await (_db.update(_db.tournaments)..where((x) => x.id.equals(tournamentId)))
        .write(TournamentsCompanion(playersJson: Value(jsonEncode(players))));
    await _pushAll();
  }

  /// توليد البراكت — إقصاء مباشر (single elimination)، مع bye تلقائي لو عدد
  /// اللاعبين مش قوة لـ 2.
  Future<void> startTournament(String tournamentId) async {
    final t = await (_db.select(_db.tournaments)..where((x) => x.id.equals(tournamentId))).getSingle();
    final players = List<Map<String, dynamic>>.from(jsonDecode(t.playersJson) as List);
    if (players.length < 2) return;

    final shuffled = List<Map<String, dynamic>>.from(players)..shuffle(Random());
    var bracketSize = 1;
    while (bracketSize < shuffled.length) {
      bracketSize *= 2;
    }
    while (shuffled.length < bracketSize) {
      shuffled.add({'id': null, 'name': 'BYE'});
    }

    final firstRound = <Map<String, dynamic>>[];
    for (var i = 0; i < shuffled.length; i += 2) {
      final p1 = shuffled[i];
      final p2 = shuffled[i + 1];
      final isBye = p1['id'] == null || p2['id'] == null;
      firstRound.add({
        'id': '${tournamentId}_r0_m${i ~/ 2}',
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
    await _pushAll();
    await _maybeGenerateNextRound(tournamentId);
  }

  Future<void> setMatchWinner(String tournamentId, int roundIndex, int matchIndex, Map<String, dynamic> winner) async {
    final t = await (_db.select(_db.tournaments)..where((x) => x.id.equals(tournamentId))).getSingle();
    final rounds = List<List<dynamic>>.from(
      (jsonDecode(t.roundsJson) as List).map((r) => List<dynamic>.from(r as List)),
    );
    final match = Map<String, dynamic>.from(rounds[roundIndex][matchIndex] as Map);
    match['winner'] = winner;
    rounds[roundIndex][matchIndex] = match;

    await (_db.update(_db.tournaments)..where((x) => x.id.equals(tournamentId)))
        .write(TournamentsCompanion(roundsJson: Value(jsonEncode(rounds))));
    await _pushAll();
    await _maybeGenerateNextRound(tournamentId);
  }

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
      await _pushAll();
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
    await _pushAll();
    await _maybeGenerateNextRound(tournamentId);
  }

  Future<void> delete(String tournamentId) async {
    await (_db.delete(_db.tournaments)..where((x) => x.id.equals(tournamentId))).go();
    await _pushAll();
  }

  Future<void> _pushAll() => ref.read(syncServiceProvider).pushTournamentsImmediate();
}
