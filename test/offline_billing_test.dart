import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psapp_flutter/data/local/database.dart';
import 'package:psapp_flutter/features/devices/devices_controller.dart';
import 'package:psapp_flutter/features/drink_tables/drink_tables_controller.dart';
import 'package:psapp_flutter/features/shifts/shifts_controller.dart';
import 'package:psapp_flutter/features/tables/tables_controller.dart';
import 'package:psapp_flutter/providers/core_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    await db.into(db.menuItems).insert(MenuItemsCompanion.insert(itemName: 'Tea', price: 10));
    await db.into(db.inventoryItems).insert(
      InventoryItemsCompanion.insert(itemName: 'Tea', quantity: const Value(5)),
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('closing a device twice records one sale and deducts stock once', () async {
    await db.into(db.devices).insert(DevicesCompanion.insert(
      deviceId: const Value(0),
      displayName: 'PS 01',
      startTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60),
      ordersJson: const Value('{"Tea":2}'),
    ));
    final controller = container.read(devicesControllerProvider);
    final results = await Future.wait([
      controller.stop(0, closedBy: 'Cashier'),
      controller.stop(0, closedBy: 'Cashier'),
    ]);
    expect(results.where((result) => result != null).length, 1);
    final invoice = await db.select(db.historyRecords).getSingle();
    expect(invoice.buffetCost, 20);
    expect(invoice.cashier, 'Cashier');
    expect((await db.select(db.inventoryItems).getSingle()).quantity, 3);
    expect((await db.select(db.devices).getSingle()).startTime, isNull);
  });

  test('game checkout rejects an unset fixed rate and keeps the active session', () async {
    await db.into(db.gameTables).insert(GameTablesCompanion.insert(
      tableId: const Value(0), name: 'Table 01', rate: const Value(60),
      startTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000 - 600),
    ));
    final controller = container.read(tablesControllerProvider);
    expect(await controller.stop(0, byGame: true), isNull);
    expect((await db.select(db.gameTables).getSingle()).startTime, isNotNull);
    expect(await controller.stop(0, byGame: false), isNotNull);
    expect((await db.select(db.historyRecords).get()).length, 1);
  });

  test('drink checkout is empty after payment and writes only one invoice', () async {
    await db.into(db.drinkTables).insert(DrinkTablesCompanion.insert(
      tableId: const Value(0), name: 'Drinks 01', ordersJson: const Value('{"Tea":1}'),
    ));
    final controller = container.read(drinkTablesControllerProvider);
    expect(await controller.checkout(0), 10);
    expect(await controller.checkout(0), isNull);
    expect((await db.select(db.inventoryItems).getSingle()).quantity, 4);
    expect((await db.select(db.historyRecords).get()).length, 1);
  });

  test('shift totals include only receipts from that cashier', () async {
    final controller = container.read(shiftsControllerProvider);
    await controller.startShift('Cashier');
    final clock = DateTime.now();
    await db.update(db.openShifts).write(OpenShiftsCompanion(
      startTime: Value(clock.subtract(const Duration(minutes: 2)).toIso8601String()),
    ));
    final now = clock.subtract(const Duration(minutes: 1)).toIso8601String();
    for (final cashier in ['Cashier', 'Another cashier']) {
      await db.into(db.historyRecords).insert(HistoryRecordsCompanion.insert(
        name: 'Test invoice', total: 25, cashier: Value(cashier),
        date: now, createdAt: now,
      ));
    }
    final closed = await controller.endShift('Cashier');
    expect(closed['total_revenue'], 25);
    expect(closed['sessions_count'], 1);
    expect(await controller.endShift('Cashier'), isEmpty);
  });
}
