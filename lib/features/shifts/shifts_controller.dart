import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/audit_log_service.dart';
import '../../providers/core_providers.dart';

final shiftsControllerProvider = Provider<ShiftsController>((ref) => ShiftsController(ref));

class ShiftOpenResult {
  final bool success;
  final String? lockedByOtherDeviceMessage;
  ShiftOpenResult({required this.success, this.lockedByOtherDeviceMessage});
}

class ShiftsController {
  final Ref ref;
  ShiftsController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);

  Future<ShiftOpenResult> startShift(String cashierName) async {
    final existing = await (_db.select(_db.openShifts)..where((t) => t.cashierName.equals(cashierName))).getSingleOrNull();
    if (existing != null) {
      // شيفت مفتوح محليًا بالفعل — كمّل عادي (استئناف بعد إعادة تشغيل التطبيق مثلًا)
      return ShiftOpenResult(success: true);
    }

    await _db.into(_db.openShifts).insert(
          OpenShiftsCompanion.insert(
            cashierName: cashierName,
            startTime: DateTime.now().toIso8601String(),
            isLocal: const Value(true),
          ),
        );
    AuditLogService.log(action: AuditAction.shiftStarted, actionDetails: 'بدأ شيفت — $cashierName');
    return ShiftOpenResult(success: true);
  }

  /// إنهاء الشيفت — بيحسب ملخص من سجلات التاريخ اللي حصلت في نفس الفترة،
  /// وينقله لـ shifts_history، ويشيله من open_shifts.
  Future<Map<String, dynamic>> endShift(String cashierName) => _db.transaction(() async {
    final shift = await (_db.select(_db.openShifts)..where((t) => t.cashierName.equals(cashierName))).getSingleOrNull();
    if (shift == null) return {};

    final startTime = DateTime.parse(shift.startTime);
    final endTime = DateTime.now();

    final allHistory = await _db.select(_db.historyRecords).get();
    final shiftHistory = allHistory.where((r) {
      final created = DateTime.tryParse(r.createdAt);
      return created != null &&
          created.isAfter(startTime) && created.isBefore(endTime) &&
          r.cashier == cashierName;
    }).toList();

    final totalRevenue = shiftHistory.fold<double>(0, (s, r) => s + r.total);
    final transactions = shiftHistory
        .map((r) => {'name': r.name, 'total': r.total, 'time_cost': r.timeCost, 'buffet_cost': r.buffetCost, 'date': r.date})
        .toList();

    await _db.into(_db.shiftsHistory).insert(
          ShiftsHistoryCompanion.insert(
            cashierName: cashierName,
            startTime: shift.startTime,
            endTime: Value(endTime.toIso8601String()),
            transactionsJson: Value(jsonEncode(transactions)),
          ),
        );
    await (_db.delete(_db.openShifts)..where((t) => t.cashierName.equals(cashierName))).go();

    AuditLogService.log(
      action: AuditAction.shiftEnded,
      actionDetails: 'أنهى شيفت — $cashierName (${totalRevenue.toStringAsFixed(1)} ج)',
    );

    return {
      'total_revenue': totalRevenue,
      'sessions_count': shiftHistory.length,
      'duration': endTime.difference(startTime),
    };
  });
}
