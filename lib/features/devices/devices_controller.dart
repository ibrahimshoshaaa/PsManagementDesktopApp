import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/remote/audit_log_service.dart';
import '../../domain/device_logic.dart';
import '../../providers/core_providers.dart';

final devicesControllerProvider = Provider<DevicesController>((ref) {
  return DevicesController(ref);
});

class DevicesController {
  final Ref ref;
  DevicesController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> _pushDevice(int deviceId) => ref.read(syncServiceProvider).pushDeviceImmediate(deviceId);

  /// تشغيل جهاز فاضي.
  Future<void> start(int deviceId, {required String mode, int? minutes}) async {
    if (minutes != null && minutes <= 0) return;
    final device = await (_db.select(_db.devices)..where((t) => t.deviceId.equals(deviceId))).getSingleOrNull();
    if (device == null || device.isActive) return;
    final updated = await (_db.update(_db.devices)
          ..where((t) => t.deviceId.equals(deviceId) & t.startTime.isNull()))
        .write(DevicesCompanion(
        status: const Value('شغال'),
        mode: Value(mode),
        startTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        addedSeconds: const Value(0),
        isPaused: const Value(false),
        pauseStartTime: const Value(null),
        isCountdown: Value(minutes != null),
        countdownTotalSeconds: Value(minutes == null ? null : minutes * 60),
        countdownAlertSent: const Value(false),
        sessionLogJson: const Value('[]'),
      ));
    if (updated == 0) return;
    await _pushDevice(deviceId);
    AuditLogService.logDevice(
      action: AuditAction.deviceStart,
      deviceName: device.displayName,
      deviceType: device.deviceType,
    );
  }

  Future<bool> recordMatch(int deviceId, String mode) async {
    final config = await _db.readConfigOnce();
    if (!config.matchEnabled) return false;
    final device = await (_db.select(_db.devices)..where((t) => t.deviceId.equals(deviceId))).getSingleOrNull();
    if (device == null || device.isActive) return false;
    final prices = {for (final price in await _db.select(_db.prices).get()) price.priceKey: price.amount};
    final price = device.copyWith(mode: mode).matchPrice(prices).toDouble();
    final date = DateTime.now().toIso8601String();
    final cashier = ref.read(sessionProvider).cashierName ?? 'أدمن';
    await _db.into(_db.historyRecords).insert(HistoryRecordsCompanion.insert(
      name: device.displayName,
      deviceType: Value(device.deviceType),
      isMatch: const Value(true),
      total: price,
      timeCost: Value(price),
      cashier: Value(cashier),
      date: date,
      createdAt: date,
    ));
    await ref.read(syncServiceProvider).appendHistoryRecord({
      'id': deviceId,
      'name': device.displayName,
      'device_type': device.deviceType,
      'play_mode': mode,
      'duration': '1 ماتش',
      'elapsed_seconds': 0,
      'time_cost': price,
      'buffet_cost': 0.0,
      'total': price,
      'orders': <String, int>{},
      'date': date,
      'is_match': true,
      'cashier': cashier,
    });
    AuditLogService.logDevice(
      action: AuditAction.matchRecorded,
      deviceName: device.displayName,
      deviceType: device.deviceType,
    );
    return true;
  }

  Future<void> pause(int deviceId) async {
    await (_db.update(_db.devices)..where((t) => t.deviceId.equals(deviceId))).write(
      DevicesCompanion(
        isPaused: const Value(true),
        pauseStartTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ),
    );
    await _pushDevice(deviceId);
  }

  Future<void> resume(int deviceId) async {
    final device = await (_db.select(_db.devices)..where((t) => t.deviceId.equals(deviceId))).getSingle();
    if (!device.isPaused || device.pauseStartTime == null || device.startTime == null) return;
    // الوقت اللي فات وإحنا متوقفين بيتضاف كـ addedSeconds عشان يفضل العداد صح
    // بعد الاستئناف (زي resumeDevice في الموبايل: بينقل start_time للأمام).
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final pausedDuration = now - device.pauseStartTime!;
    await (_db.update(_db.devices)..where((t) => t.deviceId.equals(deviceId))).write(
      DevicesCompanion(
        isPaused: const Value(false),
        pauseStartTime: const Value.absent(),
        startTime: Value(device.startTime! + pausedDuration),
      ),
    );
    await _pushDevice(deviceId);
  }

  /// إلغاء الجلسة من غير حساب (زي device_cancel في سجل التدقيق) — الجهاز
  /// يرجع "متاح" على طول من غير ما يتسجل أي فاتورة أو history record.
  Future<void> cancel(int deviceId) async {
    final device = await (_db.select(_db.devices)..where((t) => t.deviceId.equals(deviceId))).getSingleOrNull();
    await (_db.update(_db.devices)..where((t) => t.deviceId.equals(deviceId))).write(
      const DevicesCompanion(
        status: Value('متاح'),
        mode: Value('normal'),
        addedSeconds: Value(0),
        isPaused: Value(false),
        ordersJson: Value('{}'),
        isCountdown: Value(false),
        countdownAlertSent: Value(false),
      ),
    );
    await _db.customStatement(
      'UPDATE devices SET start_time = NULL, pause_start_time = NULL, countdown_total_seconds = NULL WHERE device_id = ?',
      [deviceId],
    );
    await _pushDevice(deviceId);
    if (device != null) {
      AuditLogService.logDevice(action: AuditAction.deviceCancel, deviceName: device.displayName, deviceType: device.deviceType);
    }
  }

  Future<bool> transferSession(int sourceId, int destinationId) async {
    if (sourceId == destinationId) return false;
    final moved = await _db.transaction(() async {
      final source = await (_db.select(_db.devices)
            ..where((t) => t.deviceId.equals(sourceId)))
          .getSingleOrNull();
      final destination = await (_db.select(_db.devices)
            ..where((t) => t.deviceId.equals(destinationId)))
          .getSingleOrNull();
      if (source == null || destination == null ||
          !source.isActive || destination.isActive ||
          source.deviceType != destination.deviceType) {
        return false;
      }
      await (_db.update(_db.devices)..where((t) => t.deviceId.equals(destinationId)))
          .write(DevicesCompanion(
        status: const Value('شغال'),
        mode: Value(source.mode),
        startTime: Value(source.startTime),
        addedSeconds: Value(source.addedSeconds),
        isPaused: Value(source.isPaused),
        pauseStartTime: Value(source.pauseStartTime),
        ordersJson: Value(source.ordersJson),
        timerAlertMinutes: Value(source.timerAlertMinutes),
        isCountdown: Value(source.isCountdown),
        countdownTotalSeconds: Value(source.countdownTotalSeconds),
        countdownAlertSent: Value(source.countdownAlertSent),
        sessionLogJson: Value(source.sessionLogJson),
      ));
      await (_db.update(_db.devices)..where((t) => t.deviceId.equals(sourceId)))
          .write(const DevicesCompanion(
        status: Value('متاح'),
        mode: Value('normal'),
        startTime: Value(null),
        addedSeconds: Value(0),
        isPaused: Value(false),
        pauseStartTime: Value(null),
        ordersJson: Value('{}'),
        timerAlertMinutes: Value(null),
        isCountdown: Value(false),
        countdownTotalSeconds: Value(null),
        countdownAlertSent: Value(false),
        sessionLogJson: Value('[]'),
      ));
      AuditLogService.logDevice(
        action: AuditAction.deviceTransfer,
        deviceName: source.displayName,
        deviceType: source.deviceType,
        extra: destination.displayName,
      );
      return true;
    });
    if (moved) await ref.read(syncServiceProvider).pushAllDevicesImmediate();
    return moved;
  }

  Future<void> setTimerAlert(int deviceId, int? minutes) async {
    await (_db.update(_db.devices)..where((t) => t.deviceId.equals(deviceId)))
        .write(DevicesCompanion(timerAlertMinutes: Value(minutes)));
    await _pushDevice(deviceId);
  }

  Future<void> setCountdown(int deviceId, int? totalMinutes) async {
    await (_db.update(_db.devices)..where((t) => t.deviceId.equals(deviceId))).write(
      DevicesCompanion(
        isCountdown: Value(totalMinutes != null),
        countdownTotalSeconds: Value(totalMinutes != null ? totalMinutes * 60 : null),
        countdownAlertSent: const Value(false),
      ),
    );
    await _pushDevice(deviceId);
  }

  Future<void> addOrder(int deviceId, String itemName, int deltaQty) async {
    final device = await (_db.select(_db.devices)..where((t) => t.deviceId.equals(deviceId))).getSingle();
    final orders = Map<String, int>.from(jsonDecode(device.ordersJson) as Map);
    final newQty = (orders[itemName] ?? 0) + deltaQty;
    if (newQty <= 0) {
      orders.remove(itemName);
    } else {
      orders[itemName] = newQty;
    }
    await (_db.update(_db.devices)..where((t) => t.deviceId.equals(deviceId)))
        .write(DevicesCompanion(ordersJson: Value(jsonEncode(orders))));
    await _pushDevice(deviceId);
  }

  /// إنهاء الجلسة — يحسب التكلفة، يسجّل في السجل، ويرجّع الجهاز لحالة "متاح".
  Future<Map<String, dynamic>> stop(int deviceId, {required String closedBy}) async {
    final device = await (_db.select(_db.devices)..where((t) => t.deviceId.equals(deviceId))).getSingle();
    final prices = {for (final p in await _db.select(_db.prices).get()) p.priceKey: p.amount};
    final menu = {for (final m in await _db.select(_db.menuItems).get()) m.itemName: m.price};

    final orders = Map<String, int>.from(jsonDecode(device.ordersJson) as Map);
    final timeCost = device.calculateTimePrice(prices);
    final buffetCost = device.buffetPrice(orders, menu);
    final total = timeCost + buffetCost;
    final elapsed = device.elapsedSeconds;

    final record = HistoryRecordsCompanion.insert(
      name: device.displayName,
      deviceType: Value(device.deviceType),
      isMatch: const Value(false),
      isGame: const Value(false),
      total: total,
      timeCost: Value(timeCost),
      buffetCost: Value(buffetCost),
      elapsedSeconds: Value(elapsed),
      ordersJson: Value(jsonEncode(orders)),
      cashier: Value(closedBy),
      date: DateTime.now().toString(),
      createdAt: DateTime.now().toIso8601String(),
    );
    await _db.into(_db.historyRecords).insert(record);

    // تحديث مبيعات اليوم (لخصم المخزون تلقائيًا) — لكل صنف اتباع
    for (final entry in orders.entries) {
      final existing = await (_db.select(_db.dailyInventorySummary)..where((t) => t.itemName.equals(entry.key)))
          .getSingleOrNull();
      await _db.into(_db.dailyInventorySummary).insertOnConflictUpdate(
            DailyInventorySummaryCompanion.insert(
              itemName: entry.key,
              quantitySold: Value((existing?.quantitySold ?? 0) + entry.value),
            ),
          );
    }

    await (_db.update(_db.devices)..where((t) => t.deviceId.equals(deviceId))).write(
      const DevicesCompanion(
        status: Value('متاح'),
        mode: Value('normal'),
        startTime: Value.absent(),
        addedSeconds: Value(0),
        isPaused: Value(false),
        pauseStartTime: Value.absent(),
        ordersJson: Value('{}'),
        isCountdown: Value(false),
        countdownTotalSeconds: Value.absent(),
        countdownAlertSent: Value(false),
      ),
    );
    // start_time لازم يتصفر فعليًا (null) مش يتحط absent بس — بنعمل تحديث تاني صريح
    await _db.customStatement(
      'UPDATE devices SET start_time = NULL, pause_start_time = NULL, countdown_total_seconds = NULL WHERE device_id = ?',
      [deviceId],
    );

    await _pushDevice(deviceId);
    await ref.read(syncServiceProvider).appendHistoryRecord({
      'name': device.displayName,
      'device_type': device.deviceType,
      'is_match': false,
      'is_game': false,
      'total': total,
      'time_cost': timeCost,
      'buffet_cost': buffetCost,
      'elapsed_seconds': elapsed,
      'orders': orders,
      'date': DateTime.now().toString(),
      'cashier': closedBy,
    });
    AuditLogService.logDevice(
      action: AuditAction.deviceStop,
      deviceName: device.displayName,
      deviceType: device.deviceType,
      extra: '${total.toStringAsFixed(1)} ج',
    );

    return {'total': total, 'time_cost': timeCost, 'buffet_cost': buffetCost};
  }
}
