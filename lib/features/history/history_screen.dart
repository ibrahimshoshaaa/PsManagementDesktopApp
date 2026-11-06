import '../shared/screen_ui.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import '../../services/export/pdf_export_service.dart';
import '../../services/export/excel_export_service.dart';
import '../../services/export/export_paths.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _query = '';
  DateTime? _date;

  @override
  Widget build(BuildContext context) {
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

        final visible = records.where((row) {
          final date = DateTime.tryParse(row.createdAt)?.toLocal();
          return (_date == null || DateUtils.isSameDay(date, _date)) &&
              '${row.name} ${row.cashier ?? ''} ${row.rowId}'.toLowerCase().contains(_query);
        }).toList();
        final totalToday = todayRecords.fold<double>(0, (sum, r) => sum + r.total);
        final timeToday = todayRecords.fold<double>(0, (sum, r) => sum + r.timeCost);
        final buffetToday = todayRecords.fold<double>(0, (sum, r) => sum + r.buffetCost);

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          ScreenIntro(
            icon: Icons.receipt_long_outlined, title: 'سجل الفواتير',
            description: 'اضغط على فاتورة عشان تشوف تفاصيلها أو تفتحها للطباعة.',
            actions: [
              OutlinedButton.icon(
                    onPressed: () => _exportPdf(context, ref, shopName: ref.read(appConfigProvider).valueOrNull?.shopName ?? '', todayRecords: todayRecords),
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportExcel(context, ref, visible),
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
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextField(
                  onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'ابحث باسم الجهاز أو الكاشير أو رقم الفاتورة'),
                )),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(context: context, initialDate: _date ?? today,
                      firstDate: DateTime(2000), lastDate: today);
                    if (date != null && mounted) setState(() => _date = date);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_date == null ? 'كل التواريخ' : '${_date!.day}/${_date!.month}/${_date!.year}'),
                ),
                if (_date != null) IconButton(tooltip: 'إلغاء الفلتر', onPressed: () => setState(() => _date = null), icon: const Icon(Icons.clear)),
              ]),
              const SizedBox(height: 12),
              Expanded(
                child: visible.isEmpty
                    ? const ScreenEmpty(icon: Icons.receipt_long_outlined, title: 'مفيش سجلات لسه', hint: 'جرّب تغيّر البحث أو التاريخ، أو اقفل جلسة عشان تظهر أول فاتورة.')
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = visible[i];
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
                            onTap: () => _preview(r),
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

  Future<void> _preview(HistoryRecordRow record) async {
    final db = ref.read(databaseProvider);
    final id = record.localCustomerId;
    final customer = id == null ? null :
        await (db.select(db.localCustomers)..where((row) => row.id.equals(id))).getSingleOrNull();
    if (!mounted) return;
    final shop = ref.read(appConfigProvider).valueOrNull?.shopName ?? '';
    final orders = Map<String, dynamic>.from(jsonDecode(record.ordersJson) as Map);
    var busy = false;
    await showDialog<void>(context: context, builder: (dialog) => StatefulBuilder(
      builder: (context, redraw) => AlertDialog(
        title: Text('فاتورة رقم ${record.rowId} • ${record.name}'),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(record.date),
            if (record.cashier != null) Text('الكاشير: ${record.cashier}'),
            if (customer != null) Text('العميل: ${customer.name}'),
            const Divider(),
            for (final item in orders.entries) ListTile(contentPadding: EdgeInsets.zero,
              title: Text(item.key), trailing: Text('× ${item.value}')),
            Text('اللعب: ${record.timeCost.toStringAsFixed(2)} ج'),
            Text('البوفيه: ${record.buffetCost.toStringAsFixed(2)} ج'),
            Text('الإجمالي: ${record.total.toStringAsFixed(2)} ج',
              style: const TextStyle(color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('رجوع')),
          FilledButton.icon(
            onPressed: busy ? null : () async {
              redraw(() => busy = true);
              try {
                final path = await PdfExportService.exportInvoice(shopName: shop, record: record, customerName: customer?.name);
                if (Platform.isWindows) await Process.start('explorer.exe', [path]);
                if (context.mounted) _showSavedSnackbar(context, path);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح ملف الفاتورة')));
                }
              } finally {
                if (context.mounted) redraw(() => busy = false);
              }
            },
            icon: const Icon(Icons.print_outlined),
            label: const Text('فتح PDF للطباعة'),
          ),
        ],
      ),
    ));
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
