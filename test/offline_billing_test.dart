import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psapp_flutter/data/local/database.dart';
import 'package:psapp_flutter/features/devices/devices_controller.dart';
import 'package:psapp_flutter/features/debts/debts_controller.dart';
import 'package:psapp_flutter/features/tournaments/tournaments_controller.dart';
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

  test('device changes rate mid-session and links the receipt to its customer', () async {
    final customerId = await db.into(db.localCustomers).insert(
      LocalCustomersCompanion.insert(name: 'Customer', phone: '01012345678'),
    );
    await db.into(db.devices).insert(DevicesCompanion.insert(
      deviceId: const Value(0),
      displayName: 'PS 01',
    ));
    final controller = container.read(devicesControllerProvider);
    await controller.start(0, mode: 'normal', customerId: customerId);
    final epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update(db.devices).write(DevicesCompanion(startTime: Value(epoch - 3600)));
    await controller.switchMode(0);
    final device = await db.select(db.devices).getSingle();
    expect(device.mode, 'multi');
    expect(device.settledTimeCost, closeTo(25, 0.02));
    await db.update(db.devices).write(DevicesCompanion(
      isPaused: const Value(true),
      pauseStartTime: Value(device.startTime! + device.segmentStartSeconds + 3600),
    ));
    await controller.addOrders(0, {'Tea': 2});
    final result = await controller.stop(0, closedBy: 'Cashier');
    expect(result!['time_cost'], closeTo(60, 0.02));
    expect(result['total'], closeTo(80, 0.02));
    final invoice = await db.select(db.historyRecords).getSingle();
    expect(invoice.localCustomerId, customerId);
    final customer = await db.select(db.localCustomers).getSingle();
    expect(customer.visits, 1);
    expect(customer.totalSpent, closeTo(80, 0.02));
  });

  test('overstock buffet selection rolls back all changes', () async {
    await db.into(db.devices).insert(DevicesCompanion.insert(
      deviceId: const Value(0),
      displayName: 'PS 01',
      startTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
    ));
    await db.into(db.menuItems).insert(MenuItemsCompanion.insert(itemName: 'Coffee', price: 15));
    final controller = container.read(devicesControllerProvider);
    await expectLater(controller.addOrders(0, {'Coffee': 1, 'Tea': 6}), throwsStateError);
    expect((await db.select(db.devices).getSingle()).ordersJson, '{}');
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

  test('open accounts share available stock, and moving a table preserves the account', () async {
    for (var i = 0; i < 2; i++) {
      await db.into(db.gameTables).insert(GameTablesCompanion.insert(
        tableId: Value(i), name: 'Table $i', rate: const Value(60),
      ));
    }
    await db.into(db.drinkTables).insert(DrinkTablesCompanion.insert(
      tableId: const Value(0), name: 'Drinks',
    ));
    final tables = container.read(tablesControllerProvider);
    final drinks = container.read(drinkTablesControllerProvider);
    await tables.start(0);
    await tables.addOrders(0, {'Tea': 4});
    await expectLater(drinks.addOrders(0, {'Tea': 2}), throwsStateError);
    expect(await tables.transfer(0, 1), isTrue);
    final rows = await db.select(db.gameTables).get();
    expect(rows.singleWhere((row) => row.tableId == 0).startTime, isNull);
    expect(rows.singleWhere((row) => row.tableId == 1).ordersJson, '{"Tea":4}');
    await drinks.addOrders(0, {'Tea': 1});
    await drinks.checkout(0);
    expect((await db.select(db.inventoryItems).getSingle()).quantity, 4);
  });

  test('debt rejects overpayment and records the actual full payment', () async {
    final controller = container.read(debtsControllerProvider);
    await controller.add(name: 'Customer', amount: 100, createdBy: 'Cashier');
    final id = (await db.select(db.debts).getSingle()).rowId;
    await expectLater(controller.addPartialPayment(id, 101, paidBy: 'Cashier'), throwsStateError);
    await controller.addPartialPayment(id, 25, paidBy: 'Cashier');
    await controller.markPaid(id, paidBy: 'Cashier');
    final row = await db.select(db.debts).getSingle();
    expect(row.paid, isTrue);
    expect(row.amount, 0);
    expect((jsonDecode(row.paymentHistoryJson) as List).map((item) => item['amount']), [25, 75]);
  });

  test('five-player tournament creates three real byes and advances the scored winner', () async {
    final controller = container.read(tournamentsControllerProvider);
    await controller.create(name: 'Cup', game: 'eFootball');
    final id = (await db.select(db.tournaments).getSingle()).id;
    for (var i = 0; i < 5; i++) {
      await controller.addPlayer(id, 'Player $i');
    }
    await controller.startTournament(id);
    var row = await db.select(db.tournaments).getSingle();
    final matches = (jsonDecode(row.roundsJson) as List).first as List;
    expect(matches.where((match) => match['is_bye'] == true).length, 3);
    expect(matches.every((match) => match['player1']['id'] != null), isTrue);
    await controller.setMatchScore(id, 0, 3, 2, 1);
    row = await db.select(db.tournaments).getSingle();
    expect(row.currentRound, 1);
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
