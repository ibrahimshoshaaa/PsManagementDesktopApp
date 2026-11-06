import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import '../../services/export/export_paths.dart';
import '../../services/export/pdf_export_service.dart';

final _closedShifts = StreamProvider.autoDispose<List<ShiftHistoryRow>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.shiftsHistory)..orderBy([(row) => OrderingTerm.desc(row.rowId)])).watch();
});

class ShiftHistoryScreen extends ConsumerWidget {
  const ShiftHistoryScreen({super.key, this.cashierName});
  final String? cashierName;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(_closedShifts).when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (_, __) => const Center(child: Text('تعذر تحميل الشيفتات')),
    data: (all) {
      final session = ref.watch(sessionProvider);
      final filter = session.role == UserRole.admin ? cashierName : session.cashierName;
      final rows = session.role == UserRole.none || (session.role == UserRole.cashier && filter == null)
          ? <ShiftHistoryRow>[] : all.where((row) => filter == null || row.cashierName == filter).toList();
      return rows.isEmpty
        ? const Center(child: Text('مفيش شيفتات مقفولة لسه'))
        : ListView.builder(padding: const EdgeInsets.all(24), itemCount: rows.length, itemBuilder: (context, index) {
            final row = rows[index];
            final transactions = (jsonDecode(row.transactionsJson) as List)
                .whereType<Map>().map((record) => Map<String, dynamic>.from(record)).toList();
            final total = transactions.fold<double>(0, (sum, record) => sum + ((record['total'] as num?)?.toDouble() ?? 0));
            final start = DateTime.tryParse(row.startTime);
            final end = DateTime.tryParse(row.endTime ?? '');
            final shop = ref.read(appConfigProvider).valueOrNull?.shopName ?? '';
            return Card(child: ExpansionTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text('${row.cashierName} • ${total.toStringAsFixed(2)} ج'),
              subtitle: Text('${start?.toLocal().toString().split('.').first ?? row.startTime} • ${transactions.length} فاتورة'),
              children: [
                for (final record in transactions) ListTile(
                  title: Text(record['name']?.toString() ?? ''),
                  subtitle: Text(record['date']?.toString() ?? ''),
                  trailing: Text('${record['total'] ?? 0} ج'),
                ),
                if (start != null && end != null) TextButton.icon(
                  onPressed: () async {
                    try {
                      final path = await PdfExportService.exportShiftReport(
                        shopName: shop, cashierName: row.cashierName, startTime: start,
                        endTime: end, transactions: transactions,
                      );
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('اتحفظ التقرير: $path'),
                          action: SnackBarAction(label: 'فتح المجلد', onPressed: openReportsFolderInExplorer)),
                      );
                    } catch (_) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تصدير الشيفت')));
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('تصدير تقرير الشيفت'),
                ),
              ],
            ));
          });
    },
  );
}
