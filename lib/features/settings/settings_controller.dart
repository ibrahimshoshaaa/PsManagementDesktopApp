import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/password_utils.dart';
import '../../data/local/database.dart';
import '../../data/local/audit_log_service.dart';
import '../../providers/core_providers.dart';

final settingsControllerProvider = Provider<SettingsController>((ref) => SettingsController(ref));

class SettingsController {
  final Ref ref;
  SettingsController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);

  // ── أجهزة ──────────────────────────────────────────────────────────────

  Future<void> addDevice({required String displayName, required String deviceType}) async {
    final existing = await _db.select(_db.devices).get();
    final nextId = existing.isEmpty ? 0 : (existing.map((d) => d.deviceId).reduce((a, b) => a > b ? a : b) + 1);
    await _db.into(_db.devices).insert(
          DevicesCompanion.insert(deviceId: Value(nextId), displayName: displayName, deviceType: Value(deviceType)),
        );
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0)))
        .write(AppConfigCompanion(numDevices: Value(existing.length + 1)));
    AuditLogService.logDevice(action: AuditAction.deviceAdded, deviceName: displayName, deviceType: deviceType);
  }

  Future<void> removeDevice(int deviceId) async {
    final device = await (_db.select(_db.devices)..where((t) => t.deviceId.equals(deviceId))).getSingleOrNull();
    await (_db.delete(_db.devices)..where((t) => t.deviceId.equals(deviceId))).go();
    final remaining = await _db.select(_db.devices).get();
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0)))
        .write(AppConfigCompanion(numDevices: Value(remaining.length)));
    if (device != null) AuditLogService.logDevice(action: AuditAction.deviceRemoved, deviceName: device.displayName, deviceType: device.deviceType);
  }

  Future<void> renameDevice(int deviceId, String newName) async {
    await (_db.update(_db.devices)..where((t) => t.deviceId.equals(deviceId)))
        .write(DevicesCompanion(displayName: Value(newName)));
  }

  // ── تربيزات ────────────────────────────────────────────────────────────

  Future<void> addTable({required String name, required int rate, String tableType = 'ping', int gamePrice = 0}) async {
    final existing = await _db.select(_db.gameTables).get();
    final nextId = existing.isEmpty ? 0 : (existing.map((t) => t.tableId).reduce((a, b) => a > b ? a : b) + 1);
    await _db.into(_db.gameTables).insert(
          GameTablesCompanion.insert(
            tableId: Value(nextId),
            name: name,
            tableType: Value(tableType),
            rate: Value(rate),
            gamePrice: Value(gamePrice),
          ),
        );
    AuditLogService.logTable(action: AuditAction.tableAdded, tableName: name);
  }

  Future<void> removeTable(int tableId) async {
    final table = await (_db.select(_db.gameTables)..where((t) => t.tableId.equals(tableId))).getSingleOrNull();
    await (_db.delete(_db.gameTables)..where((t) => t.tableId.equals(tableId))).go();
    if (table != null) AuditLogService.logTable(action: AuditAction.tableRemoved, tableName: table.name);
  }

  // ── تربيزات مشروبات ────────────────────────────────────────────────────

  Future<void> addDrinkTable({required String name}) async {
    final existing = await _db.select(_db.drinkTables).get();
    final nextId = existing.isEmpty ? 0 : (existing.map((t) => t.tableId).reduce((a, b) => a > b ? a : b) + 1);
    await _db.into(_db.drinkTables).insert(DrinkTablesCompanion.insert(tableId: Value(nextId), name: name));
    AuditLogService.logTable(action: AuditAction.drinkTableAdded, tableName: name);
  }

  Future<void> removeDrinkTable(int tableId) async {
    final table = await (_db.select(_db.drinkTables)..where((t) => t.tableId.equals(tableId))).getSingleOrNull();
    await (_db.delete(_db.drinkTables)..where((t) => t.tableId.equals(tableId))).go();
    if (table != null) AuditLogService.logTable(action: AuditAction.drinkTableRemoved, tableName: table.name);
  }

  // ── أسعار ──────────────────────────────────────────────────────────────

  Future<void> setPrice(String key, int amount) async {
    await _db.into(_db.prices).insertOnConflictUpdate(PricesCompanion.insert(priceKey: key, amount: amount));
    AuditLogService.log(action: AuditAction.pricesUpdated, actionDetails: 'عدّل سعر "$key" إلى $amount ج');
  }

  // ── كاشيرز ─────────────────────────────────────────────────────────────

  Future<void> addCashier({required String name, required String password}) async {
    await _db.into(_db.cashiers).insert(CashiersCompanion.insert(name: name, passwordHash: hashPassword(password)));
    AuditLogService.log(action: AuditAction.cashierAdded, actionDetails: 'أضاف كاشير جديد: $name');
  }

  Future<CashierRow?> _cashierWithoutOpenShift(int id) async {
    final cashier = await (_db.select(_db.cashiers)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (cashier == null) return null;
    final shift = await (_db.select(_db.openShifts)
          ..where((t) => t.cashierName.equals(cashier.name)))
        .getSingleOrNull();
    if (shift != null) throw StateError('Cashier has an open shift');
    return cashier;
  }

  Future<void> renameCashier(int id, String name) async {
    await _db.transaction(() async {
      if (await _cashierWithoutOpenShift(id) == null) return;
      await (_db.update(_db.cashiers)..where((t) => t.id.equals(id)))
          .write(CashiersCompanion(name: Value(name)));
    });
  }

  Future<void> removeCashier(int id) async {
    final cashier = await _db.transaction(() async {
      final existing = await _cashierWithoutOpenShift(id);
      if (existing == null) return null;
      await (_db.delete(_db.cashiers)..where((t) => t.id.equals(id))).go();
      return existing;
    });
    if (cashier != null) AuditLogService.log(action: AuditAction.cashierRemoved, actionDetails: 'حذف كاشير: ${cashier.name}');
  }

  Future<void> changeCashierPassword(int id, String newPassword) async {
    await (_db.update(_db.cashiers)..where((t) => t.id.equals(id)))
        .write(CashiersCompanion(passwordHash: Value(hashPassword(newPassword))));
  }

  // ── منيو ───────────────────────────────────────────────────────────────

  Future<void> saveMenuItem({
    required String name,
    required int price,
    String? categoryId,
    int? buyPrice,
    int? openingStock,
    bool editing = false,
  }) => _db.transaction(() async {
    if (name.trim().isEmpty || price < 0 || (buyPrice ?? 0) < 0 || (openingStock ?? 0) < 0) {
      throw ArgumentError('Invalid menu item');
    }
    final item = MenuItemsCompanion.insert(
      itemName: name,
      price: price,
      categoryId: Value(categoryId),
      buyPrice: Value(buyPrice),
    );
    if (editing) {
      final current = await (_db.select(_db.menuItems)..where((row) => row.itemName.equals(name)))
          .getSingleOrNull();
      if (current != null && current.price != price) await _checkMenuItemNotInUse(name);
      final changed = await (_db.update(_db.menuItems)..where((row) => row.itemName.equals(name)))
          .write(item);
      if (changed == 0) throw StateError('Item removed');
    } else {
      await _db.into(_db.menuItems).insert(item);
      if (openingStock != null) {
        await _db.into(_db.inventoryItems).insertOnConflictUpdate(
          InventoryItemsCompanion.insert(itemName: name, quantity: Value(openingStock)),
        );
      }
    }
  });

  Future<void> removeMenuItem(String name) => _db.transaction(() async {
    await _checkMenuItemNotInUse(name);
    await (_db.delete(_db.menuItems)..where((t) => t.itemName.equals(name))).go();
  });

  Future<void> _checkMenuItemNotInUse(String name) async {
    final orders = [
      for (final row in await _db.select(_db.devices).get()) row.ordersJson,
      for (final row in await _db.select(_db.gameTables).get()) row.ordersJson,
      for (final row in await _db.select(_db.drinkTables).get()) row.ordersJson,
    ];
    if (orders.any((json) => (jsonDecode(json) as Map).containsKey(name))) {
      throw StateError('الصنف موجود على حساب مفتوح. اقفل الحساب قبل تغيير سعره أو حذفه.');
    }
  }

  Future<void> addBuffetCategory({required String id, required String name, required String emoji}) async {
    final existing = await _db.select(_db.buffetCategories).get();
    await _db.into(_db.buffetCategories).insert(
          BuffetCategoriesCompanion.insert(id: id, name: name, emoji: Value(emoji), sortOrder: Value(existing.length)),
        );
  }

  // ── مخزون ──────────────────────────────────────────────────────────────

  Future<void> setInventoryQuantity(String itemName, int quantity) async {
    await _db.into(_db.inventoryItems).insertOnConflictUpdate(
          InventoryItemsCompanion.insert(itemName: itemName, quantity: Value(quantity)),
        );
  }

  // ── عام ────────────────────────────────────────────────────────────────

  Future<void> updateShopName(String name) async {
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0))).write(AppConfigCompanion(shopName: Value(name)));
    AuditLogService.log(action: AuditAction.shopNameChanged, actionDetails: 'غيّر اسم المحل إلى "$name"');
  }

  Future<void> changeAdminPassword(String newPassword) async {
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0)))
        .write(AppConfigCompanion(adminPasswordHash: Value(hashPassword(newPassword))));
    AuditLogService.log(action: AuditAction.passwordChanged, actionDetails: 'غيّر كلمة سر الأدمن');
  }

  Future<void> setMatchEnabled(bool value) async {
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0))).write(AppConfigCompanion(matchEnabled: Value(value)));
    AuditLogService.log(action: AuditAction.matchToggled, actionDetails: value ? 'فعّل نظام الماتش' : 'عطّل نظام الماتش');
  }

  Future<void> setRechargeEnabled(bool value) async {
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0)))
        .write(AppConfigCompanion(rechargeEnabled: Value(value)));
  }
}
