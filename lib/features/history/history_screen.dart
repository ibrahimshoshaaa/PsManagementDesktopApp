import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import '../../services/export/pdf_export_service.dart';
import '../../services/export/excel_export_service.dart';
import '../../services/export/export_paths.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyStreamProvider);

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('حصل خطأ: $e', style: const TextStyle(color: Colors.white))),
      data: (records) {
        final today = DateTime.now();
        final todayRecords = records.where((r) {
          final d = DateTime.tryParse(r.date) ?? DateTime.tryParse(r.createdAt);
          return d != null && d.year == today.year && d.month == today.month && d.day == today.day;
        }).toList();

        final totalToday = todayRecords.fold<double>(0, (sum, r) => sum + r.total);
        final timeToday = todayRecords.fold<double>(0, (sum, r) => sum + r.timeCost);
        final buffetToday = todayRecords.fold<double>(0, (sum, r) => sum + r.buffetCost);

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('السجل', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _exportPdf(context, ref, shopName: ref.read(appConfigProvider).valueOrNull?.shopName ?? '', todayRecords: todayRecords),
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('PDF'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _exportExcel(context, ref, records),
                    icon: const Icon(Icons.table_chart, size: 18),
                    label: const Text('Excel'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatCard(label: 'إجمالي اليوم', value: '${totalToday.toStringAsFixed(1)} ج', color: AppColors.green),
                  const SizedBox(width: 12),
                  _StatCard(label: 'وقت', value: '${timeToday.toStringAsFixed(1)} ج', color: AppColors.accent),
                  const SizedBox(width: 12),
                  _StatCard(label: 'بوفيه', value: '${buffetToday.toStringAsFixed(1)} ج', color: AppColors.orange),
                  const SizedBox(width: 12),
                  _StatCard(label: 'عدد الجلسات', value: '${todayRecords.length}', color: AppColors.amber),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: records.isEmpty
                    ? const Center(child: Text('مفيش سجلات لسه', style: TextStyle(color: Colors.white38)))
                    : ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = records[i];
                          IconData icon;
                          switch (r.deviceType) {
                            case 'table':
                              icon = Icons.table_bar;
                              break;
                            case 'drink_table':
                              icon = Icons.local_cafe;
                              break;
                            default:
                              icon = Icons.sports_esports;
                          }
                          return ListTile(
                            leading: Icon(icon, color: Colors.white54),
                            title: Text(r.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(r.date, style: TextStyle(color: Colors.white.withOpacity(0.4))),
                            trailing: Text(
                              '${r.total.toStringAsFixed(1)} ج',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
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

  Future<void> _exportPdf(BuildContext context, WidgetRef ref,
      {required String shopName, required List<HistoryRecordRow> todayRecords}) async {
    final path = await PdfExportService.exportDailyReport(
      shopName: shopName,
      date: DateTime.now(),
      records: todayRecords,
    );
    _showSavedSnackbar(context, path);
  }

  Future<void> _exportExcel(BuildContext context, WidgetRef ref, List<HistoryRecordRow> records) async {
    final path = await ExcelExportService.exportHistory(records);
    _showSavedSnackbar(context, path);
  }

  void _showSavedSnackbar(BuildContext context, String path) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('اتحفظ في: $path'),
        action: SnackBarAction(label: 'افتح المجلد', onPressed: openReportsFolderInExplorer),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
