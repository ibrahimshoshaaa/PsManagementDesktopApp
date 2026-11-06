import '../shared/screen_ui.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'archive_day.dart';
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
              ScreenIntro(
                icon: Icons.archive_outlined,
                title: 'أرشيف الفواتير',
                description: 'افتح ملخص يوم محفوظ أو اختار يوم جديد للأرشفة.',
                actions: [
                  FilledButton.icon(
                    onPressed: () => _saveDay(context, ref),
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('حفظ يوم في الأرشيف'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: archives.isEmpty
                    ? const ScreenEmpty(icon: Icons.archive_outlined, title: 'لسه مفيش أيام في الأرشيف', hint: 'تقدر تحفظ اليوم من تقرير المبيعات أو تختار يوم من هنا.')
                    : ListView.separated(
                        itemCount: archives.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final a = archives[i];
                          final records = (jsonDecode(a.recordsJson) as List).whereType<Map>().toList();
                          final recordCount = records.length;

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
                              for (final record in records) ListTile(
                                dense: true,
                                title: Text(record['name']?.toString() ?? ''),
                                subtitle: Text(record['cashier']?.toString() ?? ''),
                                trailing: Text('${record['total'] ?? 0} ج'),
                              ),
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

  Future<void> _saveDay(BuildContext context, WidgetRef ref) async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (!context.mounted || date == null) return;
    await confirmArchiveDay(context, ref.read(databaseProvider), date);
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
