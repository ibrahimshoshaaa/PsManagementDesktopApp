import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/audit_log_service.dart';
import '../../domain/device_logic.dart';
import '../../providers/core_providers.dart';

final devicesControllerProvider = Provider<DevicesController>((ref) {
  return DevicesController(ref);
});

class DevicesController {
  final Ref ref;
  DevicesController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);


  /// تشغيل جهاز فاضي.
  Future<void> start(int deviceId, {required String mode, int? minutes, int? customerId}) async {
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
        sessionLogJson: Value(_log(device.copyWith(sessionLogJson: '[]'), 'بدأت جلسة ${mode == 'multi' ? 'مالتي' : 'عادي'}')),
        settledTimeCost: const Value(0),
        segmentStartSeconds: const Value(0),
        localCustomerId: Value(customerId),
        timerAlertMinutes: const Value(null),
      ));
    if (updated == 0) return;
    AuditLogService.logDevice(
      action: AuditAction.deviceStart,
      deviceName: device.displayName,
      deviceType: device.deviceType,
    );
  }

  Future<bool> recordMatch(int deviceId, String mode, {int? customerId}) => _db.transaction(() async {
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
      localCustomerId: Value(customerId),
      total: price,
      timeCost: Value(price),
      cashier: Value(cashier),
      date: date,
      createdAt: date,
    ));
    AuditLogService.logDevice(
      action: AuditAction.matchRecorded,
      deviceName: device.displayName,
      deviceType: device.deviceType,
    );
    await _db.recordCustomerVisit(customerId, price, date);
    return true;
  });

  Future<void> pause(int deviceId) => _db.transaction(() async {
    final device = await _device(deviceId);
    if (device == null || !device.isRunning) return;
    await _write(deviceId, DevicesCompanion(
      isPaused: const Value(true),
      pauseStartTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      sessionLogJson: Value(_log(device, 'إيقاف مؤقت')),
    ));
  });

  Future<void> resume(int deviceId) => _db.transaction(() async {
    final device = await _device(deviceId);
    if (device == null || !device.isActive || !device.isPaused || device.pauseStartTime == null) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final pausedDuration = (now - device.pauseStartTime!).clamp(0, 1 << 32).toInt();
    await _write(deviceId, DevicesCompanion(
      isPaused: const Value(false),
      pauseStartTime: const Value(null),
      startTime: Value(device.startTime! + pausedDuration),
      sessionLogJson: Value(_log(device, 'استكمال الجلسة')),
    ));
  });

  Future<void> cancel(int deviceId) => _db.transaction(() async {
    if (ref.read(sessionProvider).role != UserRole.admin) return;
    final device = await _device(deviceId);
    if (device == null || !device.isActive) return;
    await _write(deviceId, _available);
    AuditLogService.logDevice(
      action: AuditAction.deviceCancel, deviceName: device.displayName, deviceType: device.deviceType,
    );
  });

  Future<void> switchMode(int id) => _db.transaction(() async {
    final device = await _device(id);
    if (device == null || !device.isRunning) return;
    final prices = {for (final row in await _db.select(_db.prices).get()) row.priceKey: row.amount};
    final elapsed = device.elapsedSeconds;
    final newMode = device.mode == 'multi' ? 'normal' : 'multi';
    await _write(id, DevicesCompanion(
      mode: Value(newMode),
      settledTimeCost: Value(device.timePriceAt(prices, elapsed)),
      segmentStartSeconds: Value(elapsed),
      sessionLogJson: Value(_log(device, 'تغيير نوع اللعب إلى ${newMode == 'multi' ? 'مالتي' : 'عادي'}')),
    ));
  });

  Future<void> adjustMinutes(int id, int minutes) => _db.transaction(() async {
    final device = await _device(id);
    if (device == null || !device.isActive || minutes == 0) return;
    final event = _log(device, 'تعديل الوقت: ${minutes > 0 ? '+' : ''}$minutes دقيقة');
    if (device.isCountdown && device.countdownTotalSeconds != null) {
      final total = (device.countdownTotalSeconds! + minutes * 60).clamp(0, 1 << 32).toInt();
      await _write(id, DevicesCompanion(
        countdownTotalSeconds: Value(total),
        countdownAlertSent: const Value(false),
        sessionLogJson: Value(event),
      ));
    } else {
      final elapsed = device.elapsedSeconds;
      final adjusted = elapsed + minutes * 60;
      final floor = device.segmentStartSeconds;
      final delta = (adjusted < floor ? floor : adjusted) - elapsed;
      await _write(id, DevicesCompanion(
        addedSeconds: Value(device.addedSeconds + delta),
        sessionLogJson: Value(event),
      ));
    }
  });

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
        sessionLogJson: Value(_log(source, 'نقل الجلسة من ${source.displayName} إلى ${destination.displayName}')),
        settledTimeCost: Value(source.settledTimeCost),
        segmentStartSeconds: Value(source.segmentStartSeconds),
        localCustomerId: Value(source.localCustomerId),
      ));
      await _write(sourceId, _available);
      AuditLogService.logDevice(
        action: AuditAction.deviceTransfer,
        deviceName: source.displayName,
        deviceType: source.deviceType,
        extra: destination.displayName,
      );
      return true;
    });
    return moved;
  }

  Future<void> setTimerAlert(int deviceId, int? minutes) async {
    await (_db.update(_db.devices)..where((t) => t.deviceId.equals(deviceId)))
        .write(DevicesCompanion(timerAlertMinutes: Value(minutes)));
  }

  Future<void> setCountdown(int deviceId, int? totalMinutes) async {
    await (_db.update(_db.devices)..where((t) => t.deviceId.equals(deviceId))).write(
      DevicesCompanion(
        isCountdown: Value(totalMinutes != null),
        countdownTotalSeconds: Value(totalMinutes != null ? totalMinutes * 60 : null),
        countdownAlertSent: const Value(false),
      ),
    );
  }

  Future<void> addOrder(int deviceId, String itemName, int deltaQty) =>
      addOrders(deviceId, {itemName: deltaQty});

  Future<void> addOrders(int deviceId, Map<String, int> changes, {int? expectedStartTime}) =>
      _db.transaction(() async {
    final device = await _device(deviceId);
    if (device == null || !device.isActive ||
        (expectedStartTime != null && device.startTime != expectedStartTime)) {
      throw StateError('Session changed');
    }
    final orders = await _db.changeBuffetOrders(device.ordersJson, changes);
    await _write(deviceId, DevicesCompanion(
      ordersJson: Value(jsonEncode(orders)),
      sessionLogJson: Value(_log(device, 'تعديل طلب البوفيه')),
    ));
  });

  Future<DeviceRow?> _device(int id) =>
      (_db.select(_db.devices)..where((row) => row.deviceId.equals(id))).getSingleOrNull();

  Future<int> _write(int id, DevicesCompanion changes) =>
      (_db.update(_db.devices)..where((row) => row.deviceId.equals(id))).write(changes);

  String _log(DeviceRow device, String note) {
    final history = jsonDecode(device.sessionLogJson) as List;
    history.add({'date': DateTime.now().toIso8601String(), 'note': note});
    return jsonEncode(history);
  }

  static const _available = DevicesCompanion(
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
    settledTimeCost: Value(0),
    segmentStartSeconds: Value(0),
    localCustomerId: Value(null),
  );

  /// إنهاء الجلسة — يحسب التكلفة، يسجّل في السجل، ويرجّع الجهاز لحالة "متاح".
  Future<Map<String, dynamic>?> stop(int deviceId, {required String closedBy}) => _db.transaction(() async {
    final device = await (_db.select(_db.devices)..where((t) => t.deviceId.equals(deviceId))).getSingle();
    if (!device.isActive) return null;
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
      localCustomerId: Value(device.localCustomerId),
      date: DateTime.now().toString(),
      createdAt: DateTime.now().toIso8601String(),
    );
    await _db.into(_db.historyRecords).insert(record);

    await _db.deductSoldItems(orders);

    await _db.recordCustomerVisit(device.localCustomerId, total, DateTime.now().toIso8601String());
    await _write(deviceId, _available);

    AuditLogService.logDevice(
      action: AuditAction.deviceStop,
      deviceName: device.displayName,
      deviceType: device.deviceType,
      extra: '${total.toStringAsFixed(1)} ج',
    );

    return {'total': total, 'time_cost': timeCost, 'buffet_cost': buffetCost};
  });
}
