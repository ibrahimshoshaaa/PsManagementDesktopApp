import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
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
              Row(
                children: [
                  const Expanded(child: Text('ملخصات الفواتير المحفوظة حسب اليوم')),
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

  Future<void> _saveDay(BuildContext context, WidgetRef ref) async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (!context.mounted || date == null) return;
    final db = ref.read(databaseProvider);
    final label = date.toIso8601String().split('T').first;
    try {
      final saved = await db.transaction(() async {
        final history = await db.select(db.historyRecords).get();
        final records = history.where((row) =>
            DateUtils.isSameDay(DateTime.tryParse(row.createdAt)?.toLocal(), date)).toList();
        if (records.isEmpty) return false;
        final summary = DailyArchivesCompanion.insert(
          date: label,
          totalTime: records.fold<double>(0, (sum, row) => sum + row.timeCost),
          totalBuffet: records.fold<double>(0, (sum, row) => sum + row.buffetCost),
          totalOverall: records.fold<double>(0, (sum, row) => sum + row.total),
          recordsJson: jsonEncode(records.map((row) => {
            'name': row.name,
            'total': row.total,
            'cashier': row.cashier,
            'date': row.date,
            'orders': row.ordersJson,
          }).toList()),
        );
        final existing = await (db.select(db.dailyArchives)..where((row) => row.date.equals(label))).get();
        if (existing.isEmpty) {
          await db.into(db.dailyArchives).insert(summary);
        } else {
          await (db.update(db.dailyArchives)..where((row) => row.rowId.equals(existing.first.rowId)))
              .write(summary);
        }
        return true;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          saved ? 'اتحفظ ملخص $label. الفواتير الأصلية موجودة في السجل.' : 'مفيش فواتير في اليوم ده.',
        )));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ الأرشيف')));
      }
    }
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
