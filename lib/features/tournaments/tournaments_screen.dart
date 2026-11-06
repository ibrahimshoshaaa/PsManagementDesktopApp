import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import 'tournaments_controller.dart';
import '../shared/operation_dialog.dart';

class TournamentsScreen extends ConsumerStatefulWidget {
  const TournamentsScreen({super.key});
  @override
  ConsumerState<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends ConsumerState<TournamentsScreen> {
  @override
  Widget build(BuildContext context) {
    final tournamentsAsync = ref.watch(tournamentsStreamProvider);

    return tournamentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('حصل خطأ: $e', style: const TextStyle(color: Colors.white))),
      data: (tournaments) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('البطولات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _showCreateDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('بطولة جديدة'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: tournaments.isEmpty
                  ? const Center(child: Text('مفيش بطولات لسه', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      itemCount: tournaments.length,
                      itemBuilder: (context, i) {
                        final t = tournaments[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.emoji_events, color: AppColors.amber),
                            title: Text(t.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text('${t.game} · ${t.status}', style: const TextStyle(color: Colors.white38)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.red),
                              onPressed: () => ref.read(tournamentsControllerProvider).delete(t.id),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => _TournamentDetailScreen(tournamentId: t.id)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) {
    var name = '', game = '', maximum = '8', fee = '0';
    return showOperationDialog(context, title: 'بطولة جديدة', action: 'إنشاء البطولة', fields: [
      TextFormField(autofocus: true, decoration: const InputDecoration(labelText: 'اسم البطولة'),
        onChanged: (value) => name = value.trim(),
        validator: (value) => value == null || value.trim().isEmpty ? 'اكتب اسم البطولة' : null),
      TextFormField(decoration: const InputDecoration(labelText: 'اللعبة'), onChanged: (value) => game = value.trim()),
      TextFormField(initialValue: maximum, decoration: const InputDecoration(labelText: 'عدد اللاعبين'),
        keyboardType: TextInputType.number, onChanged: (value) => maximum = value.trim()),
      TextFormField(initialValue: fee, decoration: const InputDecoration(labelText: 'رسوم الاشتراك بالجنيه'),
        keyboardType: TextInputType.number, onChanged: (value) => fee = value.trim()),
    ], save: () => ref.read(tournamentsControllerProvider).create(
      name: name, game: game, maxPlayers: int.tryParse(maximum) ?? 0, entryFee: int.tryParse(fee) ?? -1,
    ));
  }
}

class _TournamentDetailScreen extends ConsumerWidget {
  final String tournamentId;
  const _TournamentDetailScreen({required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(tournamentsStreamProvider).valueOrNull ?? [];
    final t = tournaments.where((x) => x.id == tournamentId).firstOrNull;
    if (t == null) return const Scaffold(body: Center(child: Text('البطولة اتحذفت')));

    final controller = ref.read(tournamentsControllerProvider);
    final players = List<Map<String, dynamic>>.from(jsonDecode(t.playersJson) as List);
    final rounds = List<List<dynamic>>.from((jsonDecode(t.roundsJson) as List).map((r) => List<dynamic>.from(r as List)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(t.name), backgroundColor: AppColors.sidebar),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: t.status == 'تسجيل'
            ? _RegistrationView(tournament: t, players: players, controller: controller)
            : _BracketView(tournament: t, rounds: rounds, controller: controller),
      ),
    );
  }
}

class _RegistrationView extends StatelessWidget {
  final TournamentRow tournament;
  final List<Map<String, dynamic>> players;
  final TournamentsController controller;
  const _RegistrationView({required this.tournament, required this.players, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(child: ListTile(
          title: Text('اللاعبون (${players.length}/${tournament.maxPlayers})'),
          subtitle: Text('${tournament.game} • اشتراك ${tournament.entryFee} ج'),
          trailing: FilledButton.icon(
            onPressed: players.length >= tournament.maxPlayers ? null : () => _add(context),
            icon: const Icon(Icons.person_add_alt_1), label: const Text('إضافة لاعب'),
          ),
        )),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              for (final player in players) Card(child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(player['name'].toString()),
                subtitle: Text(player['team']?.toString() ?? ''),
                trailing: IconButton(tooltip: 'إزالة اللاعب', icon: const Icon(Icons.person_remove_outlined),
                  onPressed: () => showOperationDialog(context, title: 'إزالة ${player['name']}؟',
                    action: 'إزالة', fields: const [], save: () => controller.removePlayer(tournament.id, player['id'].toString()))),
              )),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: players.length >= 2 ? () => showOperationDialog(context,
              title: 'ابدأ البطولة؟', action: 'توليد جدول المباريات',
              fields: const [Text('التسجيل هيقفل بعد بدء البطولة.')],
              save: () => controller.startTournament(tournament.id)) : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('ابدأ البطولة (توليد البراكت)'),
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) {
    var name = '', team = '';
    return showOperationDialog(context, title: 'إضافة لاعب', action: 'تسجيل اللاعب', fields: [
      TextFormField(autofocus: true, decoration: const InputDecoration(labelText: 'اسم اللاعب'),
        onChanged: (value) => name = value.trim(),
        validator: (value) => value == null || value.trim().isEmpty ? 'اكتب اسم اللاعب' : null),
      TextFormField(decoration: const InputDecoration(labelText: 'الفريق (اختياري)'), onChanged: (value) => team = value.trim()),
    ], save: () => controller.addPlayer(tournament.id, name, team: team));
  }
}

class _BracketView extends StatelessWidget {
  final TournamentRow tournament;
  final List<List<dynamic>> rounds;
  final TournamentsController controller;
  const _BracketView({required this.tournament, required this.rounds, required this.controller});

  @override
  Widget build(BuildContext context) {
    final winnerName = rounds.isEmpty || tournament.status != 'منتهية'
        ? null : (rounds.last.first as Map)['winner']?['name']?.toString();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (winnerName != null) Card(child: ListTile(
        leading: const Icon(Icons.emoji_events, color: AppColors.amber),
        title: Text('بطل البطولة: $winnerName'),
      )),
      Expanded(child: SingleChildScrollView(
        child: SingleChildScrollView(

      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rounds.asMap().entries.map((roundEntry) {
          final roundIndex = roundEntry.key;
          final matches = roundEntry.value.map((m) => Map<String, dynamic>.from(m as Map)).toList();
          return Padding(
            padding: const EdgeInsets.only(left: 16),
            child: SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roundIndex == rounds.length - 1 && tournament.status == 'منتهية' ? 'النهائي' : 'الجولة ${roundIndex + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...matches.asMap().entries.map((matchEntry) {
                    final matchIndex = matchEntry.key;
                    final m = matchEntry.value;
                    final p1 = Map<String, dynamic>.from(m['player1'] as Map);
                    final p2 = Map<String, dynamic>.from(m['player2'] as Map);
                    final winner = m['winner'] as Map?;
                    final isBye = m['is_bye'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            _PlayerRow(
                              name: '${p1['name']}${m['score1'] == null ? '' : '  •  ${m['score1']}'}',
                              isWinner: winner != null && winner['id'] == p1['id'],
                              onTap: null,
                            ),
                            const Divider(height: 8),
                            _PlayerRow(
                              name: '${p2['name']}${m['score2'] == null ? '' : '  •  ${m['score2']}'}',
                              isWinner: winner != null && winner['id'] == p2['id'],
                              onTap: null,
                            ),
                            if (!isBye && winner == null && roundIndex == tournament.currentRound)
                              TextButton.icon(
                                onPressed: () => _score(context, roundIndex, matchIndex, p1, p2),
                                icon: const Icon(Icons.scoreboard_outlined),
                                label: const Text('تسجيل النتيجة'),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      ))),
    ]);
  }

  Future<void> _score(BuildContext context, int round, int match, Map<String, dynamic> first, Map<String, dynamic> second) {
    var a = '', b = '';
    return showOperationDialog(context, title: 'نتيجة المباراة', action: 'حفظ النتيجة', fields: [
      TextFormField(autofocus: true, keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: first['name'].toString()), onChanged: (value) => a = value.trim()),
      TextFormField(keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: second['name'].toString()), onChanged: (value) => b = value.trim()),
    ], save: () => controller.setMatchScore(tournament.id, round, match, int.tryParse(a) ?? -1, int.tryParse(b) ?? -1));
  }
}

class _PlayerRow extends StatelessWidget {
  final String name;
  final bool isWinner;
  final VoidCallback? onTap;
  const _PlayerRow({required this.name, required this.isWinner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(isWinner ? Icons.emoji_events : Icons.circle_outlined, size: 16, color: isWinner ? AppColors.amber : Colors.white24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(color: isWinner ? Colors.white : Colors.white70, fontWeight: isWinner ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
