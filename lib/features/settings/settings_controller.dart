import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/password_utils.dart';
import '../../data/local/database.dart';
import '../../data/remote/audit_log_service.dart';
import '../../providers/core_providers.dart';

final settingsControllerProvider = Provider<SettingsController>((ref) => SettingsController(ref));

class SettingsController {
  final Ref ref;
  SettingsController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);
  void _pushDevicesAll() => ref.read(syncServiceProvider).pushAllDevicesImmediate();
  void _pushTables() => ref.read(syncServiceProvider).schedulePushTables();
  void _pushDrinkTables() => ref.read(syncServiceProvider).schedulePushDrinkTablesState();
  void _pushStatic() => ref.read(syncServiceProvider).schedulePushStatic();

  // ── أجهزة ──────────────────────────────────────────────────────────────

  Future<void> addDevice({required String displayName, required String deviceType}) async {
    final existing = await _db.select(_db.devices).get();
    final nextId = existing.isEmpty ? 0 : (existing.map((d) => d.deviceId).reduce((a, b) => a > b ? a : b) + 1);
    await _db.into(_db.devices).insert(
          DevicesCompanion.insert(deviceId: Value(nextId), displayName: displayName, deviceType: Value(deviceType)),
        );
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0)))
        .write(AppConfigCompanion(numDevices: Value(existing.length + 1)));
    _pushDevicesAll();
    _pushStatic();
    AuditLogService.logDevice(action: AuditAction.deviceAdded, deviceName: displayName, deviceType: deviceType);
  }

  Future<void> removeDevice(int deviceId) async {
    final device = await (_db.select(_db.devices)..where((t) => t.deviceId.equals(deviceId))).getSingleOrNull();
    await (_db.delete(_db.devices)..where((t) => t.deviceId.equals(deviceId))).go();
    final remaining = await _db.select(_db.devices).get();
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0)))
        .write(AppConfigCompanion(numDevices: Value(remaining.length)));
    _pushDevicesAll();
    _pushStatic();
    if (device != null) AuditLogService.logDevice(action: AuditAction.deviceRemoved, deviceName: device.displayName, deviceType: device.deviceType);
  }

  Future<void> renameDevice(int deviceId, String newName) async {
    await (_db.update(_db.devices)..where((t) => t.deviceId.equals(deviceId)))
        .write(DevicesCompanion(displayName: Value(newName)));
    _pushDevicesAll();
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
    _pushTables();
    AuditLogService.logTable(action: AuditAction.tableAdded, tableName: name);
  }

  Future<void> removeTable(int tableId) async {
    final table = await (_db.select(_db.gameTables)..where((t) => t.tableId.equals(tableId))).getSingleOrNull();
    await (_db.delete(_db.gameTables)..where((t) => t.tableId.equals(tableId))).go();
    _pushTables();
    if (table != null) AuditLogService.logTable(action: AuditAction.tableRemoved, tableName: table.name);
  }

  // ── تربيزات مشروبات ────────────────────────────────────────────────────

  Future<void> addDrinkTable({required String name}) async {
    final existing = await _db.select(_db.drinkTables).get();
    final nextId = existing.isEmpty ? 0 : (existing.map((t) => t.tableId).reduce((a, b) => a > b ? a : b) + 1);
    await _db.into(_db.drinkTables).insert(DrinkTablesCompanion.insert(tableId: Value(nextId), name: name));
    _pushDrinkTables();
    AuditLogService.logTable(action: AuditAction.drinkTableAdded, tableName: name);
  }

  Future<void> removeDrinkTable(int tableId) async {
    final table = await (_db.select(_db.drinkTables)..where((t) => t.tableId.equals(tableId))).getSingleOrNull();
    await (_db.delete(_db.drinkTables)..where((t) => t.tableId.equals(tableId))).go();
    _pushDrinkTables();
    if (table != null) AuditLogService.logTable(action: AuditAction.drinkTableRemoved, tableName: table.name);
  }

  // ── أسعار ──────────────────────────────────────────────────────────────

  Future<void> setPrice(String key, int amount) async {
    await _db.into(_db.prices).insertOnConflictUpdate(PricesCompanion.insert(priceKey: key, amount: amount));
    _pushStatic();
    AuditLogService.log(action: AuditAction.pricesUpdated, actionDetails: 'عدّل سعر "$key" إلى $amount ج');
  }

  // ── كاشيرز ─────────────────────────────────────────────────────────────

  Future<void> addCashier({required String name, required String password}) async {
    await _db.into(_db.cashiers).insert(CashiersCompanion.insert(name: name, passwordHash: hashPassword(password)));
    _pushStatic();
    AuditLogService.log(action: AuditAction.cashierAdded, actionDetails: 'أضاف كاشير جديد: $name');
  }

  Future<void> removeCashier(int id) async {
    final cashier = await (_db.select(_db.cashiers)..where((t) => t.id.equals(id))).getSingleOrNull();
    await (_db.delete(_db.cashiers)..where((t) => t.id.equals(id))).go();
    _pushStatic();
    if (cashier != null) AuditLogService.log(action: AuditAction.cashierRemoved, actionDetails: 'حذف كاشير: ${cashier.name}');
  }

  Future<void> changeCashierPassword(int id, String newPassword) async {
    await (_db.update(_db.cashiers)..where((t) => t.id.equals(id)))
        .write(CashiersCompanion(passwordHash: Value(hashPassword(newPassword))));
    _pushStatic();
  }

  // ── منيو ───────────────────────────────────────────────────────────────

  Future<void> addMenuItem({required String name, required int price, String? categoryId, int? buyPrice}) async {
    await _db.into(_db.menuItems).insert(
          MenuItemsCompanion.insert(
            itemName: name,
            price: price,
            categoryId: Value(categoryId),
            buyPrice: Value(buyPrice),
          ),
        );
    _pushStatic();
  }

  Future<void> removeMenuItem(String name) async {
    await (_db.delete(_db.menuItems)..where((t) => t.itemName.equals(name))).go();
    _pushStatic();
  }

  Future<void> addBuffetCategory({required String id, required String name, required String emoji}) async {
    final existing = await _db.select(_db.buffetCategories).get();
    await _db.into(_db.buffetCategories).insert(
          BuffetCategoriesCompanion.insert(id: id, name: name, emoji: Value(emoji), sortOrder: Value(existing.length)),
        );
    _pushStatic();
  }

  // ── مخزون ──────────────────────────────────────────────────────────────

  Future<void> setInventoryQuantity(String itemName, int quantity) async {
    await _db.into(_db.inventoryItems).insertOnConflictUpdate(
          InventoryItemsCompanion.insert(itemName: itemName, quantity: Value(quantity)),
        );
    _pushStatic();
  }

  // ── عام ────────────────────────────────────────────────────────────────

  Future<void> updateShopName(String name) async {
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0))).write(AppConfigCompanion(shopName: Value(name)));
    _pushStatic();
    AuditLogService.log(action: AuditAction.shopNameChanged, actionDetails: 'غيّر اسم المحل إلى "$name"');
  }

  Future<void> changeAdminPassword(String newPassword) async {
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0)))
        .write(AppConfigCompanion(adminPasswordHash: Value(hashPassword(newPassword))));
    _pushStatic();
    AuditLogService.log(action: AuditAction.passwordChanged, actionDetails: 'غيّر كلمة سر الأدمن');
  }

  Future<void> setMatchEnabled(bool value) async {
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0))).write(AppConfigCompanion(matchEnabled: Value(value)));
    _pushStatic();
    AuditLogService.log(action: AuditAction.matchToggled, actionDetails: value ? 'فعّل نظام الماتش' : 'عطّل نظام الماتش');
  }

  Future<void> setRechargeEnabled(bool value) async {
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0)))
        .write(AppConfigCompanion(rechargeEnabled: Value(value)));
    _pushStatic();
  }
}
