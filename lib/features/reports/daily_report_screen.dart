import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/firebase_service.dart';
import '../../data/remote/json_mappers.dart';
import '../../providers/core_providers.dart';

class DailyReportScreen extends ConsumerStatefulWidget {
  const DailyReportScreen({super.key});

  @override
  ConsumerState<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends ConsumerState<DailyReportScreen> {
  List<Map<String, dynamic>>? _cloud;
  bool _loading = false;
  int _tab = 0;

  Future<void> _refresh() async {
    final shopId = ref.read(appConfigProvider).valueOrNull?.shopId;
    if (shopId == null) return;
    setState(() => _loading = true);
    final records = await FirebaseService.getRecentHistory(shopId, limit: 1000);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (records.isNotEmpty) _cloud = records;
    });
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مفيش سجلات سحابية متاحة للعرض.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = ref.watch(historyStreamProvider).valueOrNull ?? [];
    final menu = ref.watch(menuItemsStreamProvider).valueOrNull ?? [];
    final expenses = ref.watch(expensesStreamProvider).valueOrNull ?? [];
    final today = DateTime.now();
    final todayExpenses = expenses.where(
      (row) => row.date == '${today.day}/${today.month}/${today.year}',
    ).fold<double>(0, (sum, row) => sum + row.amount);
    final records = (_cloud ?? local.map(historyRecordToJson)).where((row) {
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
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${today.day}/${today.month}/${today.year}  •  ${_cloud == null ? 'سجل الكمبيوتر' : 'السجل السحابي'}'),
              OutlinedButton.icon(
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('آخر 1000 سجل سحابي'),
              ),
              if (_cloud != null)
                TextButton(
                  onPressed: _loading ? null : () => setState(() => _cloud = null),
                  child: const Text('عرض سجل الكمبيوتر'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < tabs.length; index++)
                ChoiceChip(
                  label: Text(tabs[index]),
                  selected: _tab == index,
                  onSelected: (_) => setState(() => _tab = index),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _tab == 0
                ? ListView(
                    children: [
                      _stat('إجمالي الفواتير', _money(total)),
                      _stat('اللعب والماتشات', _money(play)),
                      _stat('البوفيه', _money(buffet)),
                      _stat('المصروفات', _money(todayExpenses)),
                      _stat('الإيراد بعد المصروفات', _money(total - todayExpenses)),
                      _stat('عدد الفواتير', records.length.toString()),
                    ],
                  )
                : ranked.isEmpty
                    ? const Center(child: Text('مفيش فواتير في القسم ده النهارده'))
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

  Widget _stat(String label, String value) => Card(
        child: ListTile(title: Text(label), trailing: Text(value)),
      );
}

double _amount(Map<String, dynamic> row, String key) =>
    (row[key] as num?)?.toDouble() ?? 0;

String _money(double value) => '${value.toStringAsFixed(2)} ج';

class _Totals {
  int count = 0;
  double amount = 0;
}
