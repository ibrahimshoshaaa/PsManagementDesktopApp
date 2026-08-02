import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/core_providers.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivesAsync = ref.watch(dailyArchivesStreamProvider);

    return archivesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('حصل خطأ: $e', style: const TextStyle(color: Colors.white))),
      data: (archives) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الأرشيف', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Expanded(
                child: archives.isEmpty
                    ? const Center(child: Text('مفيش أيام متأرشفة لسه', style: TextStyle(color: Colors.white38)))
                    : ListView.separated(
                        itemCount: archives.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final a = archives[i];
                          int recordCount = 0;
                          try {
                            recordCount = (jsonDecode(a.recordsJson) as List).length;
                          } catch (_) {}

                          return ExpansionTile(
                            leading: const Icon(Icons.calendar_month, color: AppColors.accent),
                            title: Text(a.date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('$recordCount عملية · إجمالي: ${a.totalOverall.toStringAsFixed(1)} ج',
                                style: TextStyle(color: Colors.white.withOpacity(0.4))),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Wrap(
                                  spacing: 24,
                                  runSpacing: 8,
                                  children: [
                                    _StatChip(label: 'الوقت', value: a.totalTime, color: AppColors.accent),
                                    _StatChip(label: 'البوفيه', value: a.totalBuffet, color: AppColors.orange),
                                    _StatChip(label: 'الإجمالي', value: a.totalOverall, color: AppColors.green),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        Text('${value.toStringAsFixed(1)} ج', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}
