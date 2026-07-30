import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/remote/audit_log_service.dart';
import '../../domain/table_logic.dart';
import '../../providers/core_providers.dart';

final tablesControllerProvider = Provider<TablesController>((ref) => TablesController(ref));

class TablesController {
  final Ref ref;
  TablesController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);

  void _schedulePush() => ref.read(syncServiceProvider).schedulePushTables();

  Future<void> start(int tableId) async {
    final table = await (_db.select(_db.gameTables)..where((t) => t.tableId.equals(tableId))).getSingleOrNull();
    await (_db.update(_db.gameTables)..where((t) => t.tableId.equals(tableId))).write(
      GameTablesCompanion(
        startTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        addedSeconds: const Value(0),
        isPaused: const Value(false),
        pauseStartTime: const Value.absent(),
      ),
    );
    _schedulePush();
    if (table != null) AuditLogService.logTable(action: AuditAction.tableStart, tableName: table.name);
  }

  Future<void> pause(int tableId) async {
    await (_db.update(_db.gameTables)..where((t) => t.tableId.equals(tableId))).write(
      GameTablesCompanion(
        isPaused: const Value(true),
        pauseStartTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ),
    );
    _schedulePush();
  }

  Future<void> resume(int tableId) async {
    final table = await (_db.select(_db.gameTables)..where((t) => t.tableId.equals(tableId))).getSingle();
    if (!table.isPaused || table.pauseStartTime == null || table.startTime == null) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final pausedDuration = now - table.pauseStartTime!;
    await (_db.update(_db.gameTables)..where((t) => t.tableId.equals(tableId))).write(
      GameTablesCompanion(
        isPaused: const Value(false),
        pauseStartTime: const Value.absent(),
        startTime: Value(table.startTime! + pausedDuration),
      ),
    );
    _schedulePush();
  }

  /// إلغاء الجلسة من غير حساب.
  Future<void> cancel(int tableId) async {
    final table = await (_db.select(_db.gameTables)..where((t) => t.tableId.equals(tableId))).getSingleOrNull();
    await (_db.update(_db.gameTables)..where((t) => t.tableId.equals(tableId)))
        .write(const GameTablesCompanion(isPaused: Value(false), ordersJson: Value('{}')));
    await _db.customStatement(
      'UPDATE game_tables SET start_time = NULL, pause_start_time = NULL, added_seconds = 0 WHERE table_id = ?',
      [tableId],
    );
    _schedulePush();
    if (table != null) AuditLogService.logTable(action: AuditAction.tableCancel, tableName: table.name);
  }

  Future<void> addOrder(int tableId, String itemName, int deltaQty) async {
    final table = await (_db.select(_db.gameTables)..where((t) => t.tableId.equals(tableId))).getSingle();
    final orders = Map<String, int>.from(jsonDecode(table.ordersJson) as Map);
    final newQty = (orders[itemName] ?? 0) + deltaQty;
    if (newQty <= 0) {
      orders.remove(itemName);
    } else {
      orders[itemName] = newQty;
    }
    await (_db.update(_db.gameTables)..where((t) => t.tableId.equals(tableId)))
        .write(GameTablesCompanion(ordersJson: Value(jsonEncode(orders))));
    _schedulePush();
  }

  /// إنهاء الجلسة — [byGame] لو true بيتحاسب بسعر اللعبة الثابت (game_price)
  /// بدل سعر الساعة.
  Future<Map<String, dynamic>> stop(int tableId, {required bool byGame}) async {
    final table = await (_db.select(_db.gameTables)..where((t) => t.tableId.equals(tableId))).getSingle();
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
            date: DateTime.now().toString(),
            createdAt: DateTime.now().toIso8601String(),
          ),
        );

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

    await (_db.update(_db.gameTables)..where((t) => t.tableId.equals(tableId))).write(
      const GameTablesCompanion(
        isPaused: Value(false),
        ordersJson: Value('{}'),
      ),
    );
    await _db.customStatement(
      'UPDATE game_tables SET start_time = NULL, pause_start_time = NULL, added_seconds = 0 WHERE table_id = ?',
      [tableId],
    );

    _schedulePush();
    await ref.read(syncServiceProvider).appendHistoryRecord({
      'name': table.name,
      'device_type': 'table',
      'is_match': false,
      'is_game': byGame,
      'total': total,
      'time_cost': timeCost,
      'buffet_cost': buffetCost,
      'elapsed_seconds': elapsed,
      'orders': orders,
      'date': DateTime.now().toString(),
    });
    AuditLogService.logTable(action: AuditAction.tableStop, tableName: table.name, extra: '${total.toStringAsFixed(1)} ج');

    return {'total': total, 'time_cost': timeCost, 'buffet_cost': buffetCost};
  }
}
