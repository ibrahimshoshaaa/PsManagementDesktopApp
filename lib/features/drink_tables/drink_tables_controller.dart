import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../providers/core_providers.dart';

final drinkTablesControllerProvider = Provider<DrinkTablesController>((ref) => DrinkTablesController(ref));

class DrinkTablesController {
  final Ref ref;
  DrinkTablesController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> addOrder(int tableId, String itemName, int deltaQty) async {
    final table = await (_db.select(_db.drinkTables)..where((t) => t.tableId.equals(tableId))).getSingle();
    final orders = Map<String, int>.from(jsonDecode(table.ordersJson) as Map);
    final newQty = (orders[itemName] ?? 0) + deltaQty;
    if (newQty <= 0) {
      orders.remove(itemName);
    } else {
      orders[itemName] = newQty;
    }
    await (_db.update(_db.drinkTables)..where((t) => t.tableId.equals(tableId)))
        .write(DrinkTablesCompanion(ordersJson: Value(jsonEncode(orders))));
  }

  /// حساب الفاتورة وتصفير الأوردرات — تربيزات المشروبات مالهاش وقت، بس أوردرات.
  Future<double?> checkout(int tableId) => _db.transaction(() async {
    final table = await (_db.select(_db.drinkTables)..where((t) => t.tableId.equals(tableId))).getSingle();
    final menu = {for (final m in await _db.select(_db.menuItems).get()) m.itemName: m.price};
    final orders = Map<String, int>.from(jsonDecode(table.ordersJson) as Map);
    if (orders.isEmpty) return null;

    double total = 0;
    orders.forEach((item, qty) => total += qty * (menu[item] ?? 0));

    await _db.into(_db.historyRecords).insert(
          HistoryRecordsCompanion.insert(
            name: table.name,
            deviceType: const Value('drink_table'),
            total: total,
            timeCost: const Value(0),
            buffetCost: Value(total),
            ordersJson: Value(jsonEncode(orders)),
            cashier: Value(ref.read(sessionProvider).cashierName ?? 'أدمن'),
            date: DateTime.now().toString(),
            createdAt: DateTime.now().toIso8601String(),
          ),
        );

    await _db.deductSoldItems(orders);

    await (_db.update(_db.drinkTables)..where((t) => t.tableId.equals(tableId)))
        .write(const DrinkTablesCompanion(ordersJson: Value('{}')));


    return total;
  });
}
