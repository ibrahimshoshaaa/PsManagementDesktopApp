import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/remote/audit_log_service.dart';
import '../../data/remote/firebase_service.dart';
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

  /// يبدأ شيفت للكاشير الحالي — بيتأكد الأول إن مفيش شيفت مفتوح لنفس الاسم
  /// على جهاز تاني (زي isShiftLockedByOther في الموبايل).
  Future<ShiftOpenResult> startShift(String cashierName) async {
    final shopId = FirebaseService.currentShopId;
    if (shopId != null) {
      final remote = await FirebaseService.getAllOpenShifts(shopId);
      if (remote.containsKey(cashierName)) {
        return ShiftOpenResult(
          success: false,
          lockedByOtherDeviceMessage: 'الكاشير $cashierName عنده شيفت مفتوح بالفعل على جهاز تاني',
        );
      }
    }

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
    await ref.read(syncServiceProvider).pushOpenShiftsImmediate();
    AuditLogService.log(action: AuditAction.shiftStarted, actionDetails: 'بدأ شيفت — $cashierName');
    return ShiftOpenResult(success: true);
  }

  /// إنهاء الشيفت — بيحسب ملخص من سجلات التاريخ اللي حصلت في نفس الفترة،
  /// وينقله لـ shifts_history، ويشيله من open_shifts.
  Future<Map<String, dynamic>> endShift(String cashierName) async {
    final shift = await (_db.select(_db.openShifts)..where((t) => t.cashierName.equals(cashierName))).getSingleOrNull();
    if (shift == null) return {};

    final startTime = DateTime.parse(shift.startTime);
    final endTime = DateTime.now();

    final allHistory = await _db.select(_db.historyRecords).get();
    final shiftHistory = allHistory.where((r) {
      final created = DateTime.tryParse(r.createdAt);
      return created != null && created.isAfter(startTime) && created.isBefore(endTime);
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

    await ref.read(syncServiceProvider).pushOpenShiftsImmediate();
    ref.read(syncServiceProvider).schedulePushShiftsHistory();
    AuditLogService.log(
      action: AuditAction.shiftEnded,
      actionDetails: 'أنهى شيفت — $cashierName (${totalRevenue.toStringAsFixed(1)} ج)',
    );

    return {
      'total_revenue': totalRevenue,
      'sessions_count': shiftHistory.length,
      'duration': endTime.difference(startTime),
    };
  }

  Future<List<Map<String, dynamic>>> refreshShiftsHistoryFromRemote() async {
    final shopId = FirebaseService.currentShopId;
    if (shopId == null) return [];
    final remote = await FirebaseService.fetchShiftsHistoryOnDemand(shopId);
    for (final s in remote) {
      await _db.into(_db.shiftsHistory).insert(
            ShiftsHistoryCompanion.insert(
              cashierName: s['cashier_name']?.toString() ?? '',
              startTime: s['start_time']?.toString() ?? '',
              endTime: Value(s['end_time']?.toString()),
              transactionsJson: Value(jsonEncode(s['transactions'] ?? [])),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    return remote;
  }
}
