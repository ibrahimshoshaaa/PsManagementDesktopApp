import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../archive/archive_day.dart';

class DailyReportScreen extends ConsumerStatefulWidget {
  const DailyReportScreen({super.key});

  @override
  ConsumerState<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends ConsumerState<DailyReportScreen> {
  int _tab = 0;
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final local = ref.watch(historyStreamProvider).valueOrNull ?? [];
    final menu = ref.watch(menuItemsStreamProvider).valueOrNull ?? [];
    final expenses = ref.watch(expensesStreamProvider).valueOrNull ?? [];
    final today = _selectedDate ?? DateTime.now();
    final todayExpenses = expenses.where(
      (row) => row.date == '${today.day}/${today.month}/${today.year}',
    ).fold<double>(0, (sum, row) => sum + row.amount);
    final records = local.map(historyRecordToJson).where((row) {
      final date = DateTime.tryParse(row['date']?.toString() ?? '')?.toLocal();
      return DateUtils.isSameDay(date, today);
    }).toList();

    final total = records.fold<double>(0, (sum, row) => sum + _amount(row, 'total'));
    final play = records.fold<double>(0, (sum, row) => sum + _amount(row, 'time_cost'));
    final buffet = records.fold<double>(0, (sum, row) => sum + _amount(row, 'buffet_cost'));
    final tabs = ['الملخص', 'الأجهزة', 'التربيزات', 'المشروبات', 'البوفيه', 'الكاشير'];
    final rows = <String, _Totals>{};
    final buyPrices = {for (final item in menu) item.itemName: item.buyPrice};
    if (_tab > 0) {
      for (final record in records) {
        final type = record['device_type'];
        final include = switch (_tab) {
          1 => type == 'ps4' || type == 'ps5',
          2 => type == 'table',
          3 => type == 'drink_table',
          _ => true,
        };
        if (!include) continue;
        if (_tab == 4) {
          final orders = record['orders'];
          if (orders is! Map) continue;
          for (final entry in orders.entries) {
            final name = entry.key.toString();
            final quantity = (entry.value as num?)?.toInt() ?? 0;
            final row = rows.putIfAbsent(name, _Totals.new);
            row.count += quantity;
            row.amount += (buyPrices[name] ?? 0) * quantity;
          }
        } else {
          final key = _tab == 5 ? 'cashier' : 'name';
          final label = record[key]?.toString() ?? 'غير محدد';
          final row = rows.putIfAbsent(label, _Totals.new);
          row.count++;
          row.amount += _amount(record, 'total');
        }
      }
    }
    final ranked = rows.entries.toList()..sort((a, b) => b.value.count.compareTo(a.value.count));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [Color(0xFF234447), Color(0xFF17253B)]),
            ),
            child: Wrap(
              spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('تقرير المبيعات', style: Theme.of(context).textTheme.headlineSmall),
                  Text('${today.day}/${today.month}/${today.year}  •  ${records.length} فاتورة'),
                ]),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(context: context, initialDate: today,
                      firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (date != null && mounted) setState(() => _selectedDate = date);
                  },
                  icon: const Icon(Icons.calendar_today_outlined), label: const Text('اختيار يوم'),
                ),
                if (_selectedDate != null)
                  TextButton(onPressed: () => setState(() => _selectedDate = null), child: const Text('الرجوع لليوم')),
                FilledButton.icon(
                  onPressed: records.isEmpty ? null : () => confirmArchiveDay(context, ref.read(databaseProvider), today),
                  icon: const Icon(Icons.archive_outlined),
                  label: Text(_selectedDate == null ? 'أرشفة اليوم' : 'أرشفة التاريخ المختار'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var index = 0; index < tabs.length; index++)
                Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(
                  label: Text(tabs[index]), selected: _tab == index,
                  onSelected: (_) => setState(() => _tab = index),
                )),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _tab == 0
                ? ListView(
                    children: [
                      LayoutBuilder(builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final count = width >= 850 ? 3 : width >= 480 ? 2 : 1;
                        final cardWidth = (width - 12 * (count - 1)) / count;
                        final summaries = [
                          ('إجمالي الفواتير', _money(total), Icons.point_of_sale, AppColors.accent),
                          ('الإيراد بعد المصروفات', _money(total - todayExpenses), Icons.account_balance_wallet_outlined, AppColors.green),
                          ('المصروفات', _money(todayExpenses), Icons.payments_outlined, AppColors.orange),
                          ('اللعب والماتشات', _money(play), Icons.sports_esports_outlined, AppColors.accent),
                          ('البوفيه', _money(buffet), Icons.local_cafe_outlined, AppColors.amber),
                          ('عدد الفواتير', records.length.toString(), Icons.receipt_long, Colors.white70),
                        ];
                        return Wrap(spacing: 12, runSpacing: 12, children: [
                          for (final item in summaries)
                            SizedBox(width: cardWidth, child: _stat(item.$1, item.$2, item.$3, item.$4)),
                        ]);
                      }),
                      const SizedBox(height: 16),
                      Card(child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('توزيع المبيعات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _bar('اللعب', play, play + buffet, AppColors.accent),
                          const SizedBox(height: 12),
                          _bar('البوفيه', buffet, play + buffet, AppColors.amber),
                        ]),
                      )),
                    ],
                  )
                : ranked.isEmpty
                    ? const Center(child: Text('مفيش فواتير في القسم ده في التاريخ المختار'))
                    : ListView.builder(
                        itemCount: ranked.length,
                        itemBuilder: (context, index) {
                          final row = ranked[index];
                          return Card(
                            child: ListTile(
                              title: Text(row.key),
                              subtitle: Text(_tab == 4
                                  ? '${row.value.count} قطعة  •  تكلفة الشراء المقدرة بالأسعار الحالية'
                                  : '${row.value.count} فاتورة'),
                              trailing: Text(_money(row.value.amount)),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color accent) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(icon, color: accent, size: 26),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: TextStyle(color: accent, fontSize: 22, fontWeight: FontWeight.w700)),
        ])),
      ]),
    ),
  );

  Widget _bar(String label, double value, double total, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [Expanded(child: Text(label)), Text(_money(value))]),
      const SizedBox(height: 5),
      LinearProgressIndicator(
        value: total <= 0 ? 0 : (value / total).clamp(0.0, 1.0).toDouble(),
        color: color, minHeight: 7, borderRadius: BorderRadius.circular(8),
      ),
    ],
  );
}

double _amount(Map<String, dynamic> row, String key) =>
    (row[key] as num?)?.toDouble() ?? 0;

String _money(double value) => '${value.toStringAsFixed(2)} ج';

class _Totals {
  int count = 0;
  double amount = 0;
}

Map<String, dynamic> historyRecordToJson(HistoryRecordRow row) => {
  'name': row.name,
  'cashier': row.cashier,
  'device_type': row.deviceType,
  'total': row.total,
  'time_cost': row.timeCost,
  'buffet_cost': row.buffetCost,
  'orders': jsonDecode(row.ordersJson),
  'date': row.date,
};
