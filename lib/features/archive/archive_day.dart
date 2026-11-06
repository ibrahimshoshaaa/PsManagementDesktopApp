import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/local/database.dart';

Future<bool> archiveDay(AppDatabase db, DateTime date) => db.transaction(() async {
  final label = date.toIso8601String().split('T').first;
  final history = await db.select(db.historyRecords).get();
  final records = history.where((row) =>
      DateUtils.isSameDay(DateTime.tryParse(row.createdAt)?.toLocal(), date)).toList();
  if (records.isEmpty) return false;
  final summary = DailyArchivesCompanion.insert(
    date: label,
    totalTime: records.fold<double>(0, (sum, row) => sum + row.timeCost),
    totalBuffet: records.fold<double>(0, (sum, row) => sum + row.buffetCost),
    totalOverall: records.fold<double>(0, (sum, row) => sum + row.total),
    recordsJson: jsonEncode([
      for (final row in records)
        {'name': row.name, 'total': row.total, 'cashier': row.cashier, 'date': row.date, 'orders': row.ordersJson},
    ]),
  );
  final existing = await (db.select(db.dailyArchives)..where((row) => row.date.equals(label))).get();
  if (existing.isEmpty) {
    await db.into(db.dailyArchives).insert(summary);
  } else {
    await (db.update(db.dailyArchives)..where((row) => row.rowId.equals(existing.first.rowId))).write(summary);
  }
  return true;
});

Future<void> confirmArchiveDay(BuildContext context, AppDatabase db, DateTime day) async {
  final label = day.toIso8601String().split('T').first;
  final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
    title: Text('أرشفة يوم $label؟'),
    content: const Text('هيتحفظ ملخص الفواتير في الأرشيف، والفواتير الأصلية هتفضل في السجل.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('رجوع')),
      FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('احفظ في الأرشيف')),
    ],
  ));
  if (!context.mounted || confirmed != true) return;
  try {
    final saved = await archiveDay(db, day);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved ? 'تم حفظ ملخص اليوم في الأرشيف.' : 'مفيش فواتير في التاريخ ده.'),
    ));
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر حفظ الأرشيف.')),
    );
  }
}
