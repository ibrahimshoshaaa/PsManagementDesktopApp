import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/core_providers.dart';
import 'dashboard_stats.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyStreamProvider).valueOrNull;
    final expenses = ref.watch(expensesStreamProvider).valueOrNull;
    final debts = ref.watch(debtsStreamProvider).valueOrNull;
    final devices = ref.watch(devicesStreamProvider).valueOrNull;
    final tables = ref.watch(gameTablesStreamProvider).valueOrNull;

    if (history == null || expenses == null || debts == null || devices == null || tables == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = computeDashboardStats(
      history: history,
      expenses: expenses,
      debts: debts,
      devices: devices,
      tables: tables,
    );
    final netToday = stats.totalRevenueToday - stats.expensesToday;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لوحة التحكم', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.8,
              children: [
                _StatCard(icon: Icons.payments, label: 'إجمالي اليوم', value: '${stats.totalRevenueToday.toStringAsFixed(1)} ج', color: AppColors.green),
                _StatCard(icon: Icons.access_time, label: 'وقت', value: '${stats.timeRevenueToday.toStringAsFixed(1)} ج', color: AppColors.accent),
                _StatCard(icon: Icons.fastfood, label: 'بوفيه', value: '${stats.buffetRevenueToday.toStringAsFixed(1)} ج', color: AppColors.orange),
                _StatCard(icon: Icons.trending_up, label: 'صافي اليوم', value: '${netToday.toStringAsFixed(1)} ج', color: netToday >= 0 ? AppColors.green : AppColors.red),
                _StatCard(icon: Icons.sports_esports, label: 'أجهزة شغالة', value: '${stats.activeDevices}/${stats.totalDevices}', color: AppColors.accent),
                _StatCard(icon: Icons.table_bar, label: 'تربيزات شغالة', value: '${stats.activeTables}/${stats.totalTables}', color: AppColors.accent),
                _StatCard(icon: Icons.receipt_long, label: 'جلسات اليوم', value: '${stats.sessionsToday}', color: AppColors.amber),
                _StatCard(icon: Icons.money_off, label: 'مديونيات مستحقة', value: '${stats.unpaidDebts.toStringAsFixed(1)} ج', color: AppColors.red),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الأكتر مبيعًا اليوم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          if (stats.topItemsToday.isEmpty)
                            const Text('مفيش مبيعات لسه', style: TextStyle(color: Colors.white38))
                          else
                            ...stats.topItemsToday.entries.map(
                              (e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(e.key, style: const TextStyle(color: Colors.white70))),
                                    Text('${e.value}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المصروفات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _kv('النهاردة', '${stats.expensesToday.toStringAsFixed(1)} ج'),
                          _kv('الشهر ده', '${stats.expensesThisMonth.toStringAsFixed(1)} ج'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(k, style: const TextStyle(color: Colors.white70))),
            Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 6), Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12))]),
            const Spacer(),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
