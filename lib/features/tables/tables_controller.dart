import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/audit_log_service.dart';
import '../../domain/table_logic.dart';
import '../../providers/core_providers.dart';

final tablesControllerProvider = Provider<TablesController>((ref) => TablesController(ref));

class TablesController {
  final Ref ref;
  TablesController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);


  Future<void> start(int tableId) async {
    final table = await (_db.select(_db.gameTables)..where((t) => t.tableId.equals(tableId))).getSingleOrNull();
    await (_db.update(_db.gameTables)..where((t) => t.tableId.equals(tableId) & t.startTime.isNull())).write(
      GameTablesCompanion(
        startTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        isPaused: const Value(false),
        pauseStartTime: const Value(null),
      ),
    );
    if (table != null) AuditLogService.logTable(action: AuditAction.tableStart, tableName: table.name);
  }

  Future<void> pause(int tableId) async {
    await (_db.update(_db.gameTables)..where((t) => t.tableId.equals(tableId) & t.startTime.isNotNull() & t.isPaused.equals(false))).write(
      GameTablesCompanion(
        isPaused: const Value(true),
        pauseStartTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ),
    );
  }

  Future<void> resume(int tableId) async {
    final table = await (_db.select(_db.gameTables)..where((t) => t.tableId.equals(tableId))).getSingle();
    if (!table.isPaused || table.pauseStartTime == null || table.startTime == null) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final pausedDuration = now - table.pauseStartTime!;
    await (_db.update(_db.gameTables)..where((t) => t.tableId.equals(tableId))).write(
      GameTablesCompanion(
        isPaused: const Value(false),
        pauseStartTime: const Value(null),
        startTime: Value(table.startTime! + pausedDuration),
      ),
    );
  }

  Future<void> cancel(int tableId) => _db.transaction(() async {
    if (ref.read(sessionProvider).role != UserRole.admin) return;
    final table = await (_db.select(_db.gameTables)..where((row) => row.tableId.equals(tableId))).getSingleOrNull();
    if (table == null || table.startTime == null) return;
    await (_db.update(_db.gameTables)..where((row) => row.tableId.equals(tableId))).write(_empty);
    AuditLogService.logTable(action: AuditAction.tableCancel, tableName: table.name);
  });

  Future<bool> transfer(int sourceId, int destinationId) => _db.transaction(() async {
    if (sourceId == destinationId) return false;
    final source = await (_db.select(_db.gameTables)..where((row) => row.tableId.equals(sourceId))).getSingleOrNull();
    final destination = await (_db.select(_db.gameTables)..where((row) => row.tableId.equals(destinationId))).getSingleOrNull();
    if (source == null || destination == null || source.startTime == null ||
        destination.startTime != null || destination.ordersJson != '{}' ||
        source.rate != destination.rate || source.gamePrice != destination.gamePrice) return false;
    await (_db.update(_db.gameTables)..where((row) => row.tableId.equals(destinationId)))
        .write(GameTablesCompanion(
      startTime: Value(source.startTime), pauseStartTime: Value(source.pauseStartTime),
      addedSeconds: Value(source.addedSeconds), isPaused: Value(source.isPaused),
      ordersJson: Value(source.ordersJson), sessionLogJson: Value(source.sessionLogJson),
    ));
    await (_db.update(_db.gameTables)..where((row) => row.tableId.equals(sourceId))).write(_empty);
    return true;
  });

  Future<bool> recordGame(int tableId) => _db.transaction(() async {
    final row = await (_db.select(_db.gameTables)..where((row) => row.tableId.equals(tableId))).getSingleOrNull();
    if (row == null || row.startTime != null || row.gamePrice <= 0) return false;
    final now = DateTime.now().toIso8601String();
    final price = row.gamePrice.toDouble();
    await _db.into(_db.historyRecords).insert(HistoryRecordsCompanion.insert(
      name: row.name, deviceType: const Value('table'), isGame: const Value(true),
      total: price, timeCost: Value(price), date: now, createdAt: now,
      cashier: Value(ref.read(sessionProvider).cashierName ?? 'أدمن'),
    ));
    AuditLogService.logTable(action: AuditAction.tableGameRecord, tableName: row.name);
    return true;
  });

  static const _empty = GameTablesCompanion(
    startTime: Value(null), pauseStartTime: Value(null), addedSeconds: Value(0),
    isPaused: Value(false), ordersJson: Value('{}'), sessionLogJson: Value('[]'),
  );

  Future<void> addOrder(int tableId, String itemName, int deltaQty) =>
      addOrders(tableId, {itemName: deltaQty});

  Future<void> addOrders(int tableId, Map<String, int> changes) => _db.transaction(() async {
    final table = await (_db.select(_db.gameTables)..where((row) => row.tableId.equals(tableId))).getSingle();
    if (table.startTime == null) throw StateError('ابدأ جلسة التربيزة الأول.');
    final orders = await _db.changeBuffetOrders(table.ordersJson, changes);
    await (_db.update(_db.gameTables)..where((row) => row.tableId.equals(tableId)))
        .write(GameTablesCompanion(ordersJson: Value(jsonEncode(orders))));
  });

  /// إنهاء الجلسة — [byGame] لو true بيتحاسب بسعر اللعبة الثابت (game_price)
  /// بدل سعر الساعة.
  Future<Map<String, dynamic>?> stop(int tableId, {required bool byGame}) => _db.transaction(() async {
    final table = await (_db.select(_db.gameTables)..where((t) => t.tableId.equals(tableId))).getSingle();
    if (table.startTime == null || (byGame && table.gamePrice <= 0)) return null;
    final menu = {for (final m in await _db.select(_db.menuItems).get()) m.itemName: m.price};
    final orders = Map<String, int>.from(jsonDecode(table.ordersJson) as Map);

    final timeCost = byGame ? table.gamePrice.toDouble() : table.hourlyTimeCost;
    final buffetCost = table.buffetPrice(orders, menu);
    final total = timeCost + buffetCost;
    final elapsed = table.elapsedSeconds;

    await _db.into(_db.historyRecords).insert(
          HistoryRecordsCompanion.insert(
            name: table.name,
            deviceType: const Value('table'),
            isMatch: const Value(false),
            isGame: Value(byGame),
            total: total,
            timeCost: Value(timeCost),
            buffetCost: Value(buffetCost),
            elapsedSeconds: Value(elapsed),
            ordersJson: Value(jsonEncode(orders)),
            cashier: Value(ref.read(sessionProvider).cashierName ?? 'أدمن'),
            date: DateTime.now().toString(),
            createdAt: DateTime.now().toIso8601String(),
          ),
        );

    await _db.deductSoldItems(orders);

    await (_db.update(_db.gameTables)..where((row) => row.tableId.equals(tableId))).write(_empty);

    AuditLogService.logTable(action: AuditAction.tableStop, tableName: table.name, extra: '${total.toStringAsFixed(1)} ج');

    return {'total': total, 'time_cost': timeCost, 'buffet_cost': buffetCost};
  });
}
