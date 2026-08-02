import 'dart:convert';
import '../../data/local/database.dart';

class DashboardStats {
  final double totalRevenueToday;
  final double timeRevenueToday;
  final double buffetRevenueToday;
  final double expensesToday;
  final double expensesThisMonth;
  final double unpaidDebts;
  final int activeDevices;
  final int totalDevices;
  final int activeTables;
  final int totalTables;
  final int sessionsToday;
  final Map<String, int> topItemsToday;

  DashboardStats({
    required this.totalRevenueToday,
    required this.timeRevenueToday,
    required this.buffetRevenueToday,
    required this.expensesToday,
    required this.expensesThisMonth,
    required this.unpaidDebts,
    required this.activeDevices,
    required this.totalDevices,
    required this.activeTables,
    required this.totalTables,
    required this.sessionsToday,
    required this.topItemsToday,
  });
}

DashboardStats computeDashboardStats({
  required List<HistoryRecordRow> history,
  required List<ExpenseRow> expenses,
  required List<DebtRow> debts,
  required List<DeviceRow> devices,
  required List<GameTableRow> tables,
}) {
  final now = DateTime.now();
  bool isToday(DateTime? d) => d != null && d.year == now.year && d.month == now.month && d.day == now.day;

  final todayHistory = history.where((r) {
    final d = DateTime.tryParse(r.date) ?? DateTime.tryParse(r.createdAt);
    return isToday(d);
  }).toList();

  final totalRevenueToday = todayHistory.fold<double>(0, (s, r) => s + r.total);
  final timeRevenueToday = todayHistory.fold<double>(0, (s, r) => s + r.timeCost);
  final buffetRevenueToday = todayHistory.fold<double>(0, (s, r) => s + r.buffetCost);

  final todayExpenses = expenses.where((e) {
    final parts = e.date.split('/');
    if (parts.length != 3) return false;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    return d == now.day && m == now.month && y == now.year;
  });
  final monthExpenses = expenses.where((e) {
    final parts = e.date.split('/');
    if (parts.length != 3) return false;
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    return m == now.month && y == now.year;
  });

  final topItems = <String, int>{};
  for (final r in todayHistory) {
    final orders = Map<String, dynamic>.from(jsonDecode(r.ordersJson) as Map);
    orders.forEach((item, qty) {
      topItems[item] = (topItems[item] ?? 0) + (qty as num).toInt();
    });
  }
  final sortedTopItems = Map.fromEntries(
    topItems.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
  );

  return DashboardStats(
    totalRevenueToday: totalRevenueToday,
    timeRevenueToday: timeRevenueToday,
    buffetRevenueToday: buffetRevenueToday,
    expensesToday: todayExpenses.fold<double>(0, (s, e) => s + e.amount),
    expensesThisMonth: monthExpenses.fold<double>(0, (s, e) => s + e.amount),
    unpaidDebts: debts.where((d) => !d.paid).fold<double>(0, (s, d) => s + d.amount),
    activeDevices: devices.where((d) => d.startTime != null).length,
    totalDevices: devices.length,
    activeTables: tables.where((t) => t.startTime != null).length,
    totalTables: tables.length,
    sessionsToday: todayHistory.length,
    topItemsToday: sortedTopItems.entries.take(5).fold<Map<String, int>>({}, (m, e) => m..[e.key] = e.value),
  );
}
