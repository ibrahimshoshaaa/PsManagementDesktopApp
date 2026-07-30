import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import 'tournaments_controller.dart';

class TournamentsScreen extends ConsumerStatefulWidget {
  const TournamentsScreen({super.key});
  @override
  ConsumerState<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends ConsumerState<TournamentsScreen> {
  @override
  void initState() {
    super.initState();
    // البطولات on-demand زي الموبايل — نسحبها لما الشاشة تتفتح.
    Future.microtask(() => ref.read(tournamentsControllerProvider).refreshFromRemote());
  }

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

  void _showCreateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final gameController = TextEditingController();
    final maxPlayersController = TextEditingController(text: '8');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بطولة جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم البطولة')),
            const SizedBox(height: 12),
            TextField(controller: gameController, decoration: const InputDecoration(labelText: 'اللعبة')),
            const SizedBox(height: 12),
            TextField(controller: maxPlayersController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أقصى عدد لاعبين')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              ref.read(tournamentsControllerProvider).create(
                    name: nameController.text.trim(),
                    game: gameController.text.trim(),
                    maxPlayers: int.tryParse(maxPlayersController.text) ?? 8,
                  );
              Navigator.pop(context);
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
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
    final nameController = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('اللاعبين (${players.length}/${tournament.maxPlayers})',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم اللاعب'),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) controller.addPlayer(tournament.id, v.trim());
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  controller.addPlayer(tournament.id, nameController.text.trim());
                  nameController.clear();
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: players
                .map((p) => ListTile(
                    leading: const Icon(Icons.person, color: Colors.white54),
                    title: Text(p['name'].toString(), style: const TextStyle(color: Colors.white))))
                .toList(),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: players.length >= 2 ? () => controller.startTournament(tournament.id) : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('ابدأ البطولة (توليد البراكت)'),
          ),
        ),
      ],
    );
  }
}

class _BracketView extends StatelessWidget {
  final TournamentRow tournament;
  final List<List<dynamic>> rounds;
  final TournamentsController controller;
  const _BracketView({required this.tournament, required this.rounds, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                              name: p1['name'].toString(),
                              isWinner: winner != null && winner['id'] == p1['id'],
                              onTap: isBye || winner != null || p1['id'] == null
                                  ? null
                                  : () => controller.setMatchWinner(tournament.id, roundIndex, matchIndex, p1),
                            ),
                            const Divider(height: 8),
                            _PlayerRow(
                              name: p2['name'].toString(),
                              isWinner: winner != null && winner['id'] == p2['id'],
                              onTap: isBye || winner != null || p2['id'] == null
                                  ? null
                                  : () => controller.setMatchWinner(tournament.id, roundIndex, matchIndex, p2),
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
    );
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
