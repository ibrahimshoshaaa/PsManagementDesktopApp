import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';

import '../local/database.dart';
import 'firebase_service.dart';
import 'json_mappers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SyncService (Desktop) — منقول من services/sync_service.dart بتاع الموبايل.
//
// الفرق الأساسي عن الموبايل: هناك SharedPreferences كانت هي "الكاش المحلي"،
// هنا Drift/SQLite هو المصدر الأساسي للحقيقة (زي ما طلبت بالظبط) — فمفيش
// حاجة اسمها loadLocal/saveLocal بشكل منفصل، الـ DB نفسها دايمًا محدّثة،
// والـ SyncService بس مسؤول عن:
//   1. أول ما يشتغل: يسحب الحالة من Firebase ويطبّقها على Drift.
//   2. يفتح SSE listeners ويطبّق أي تحديث جاي من جهاز/موبايل تاني على Drift
//      (مع تجاهل أي تحديث إحنا اللي بعتناه — senderId).
//   3. لما حاجة تتغيّر محليًا (من الشاشات)، يبعتها لـ Firebase — فورًا
//      للأجهزة والسجل، ومع debounce 800ms للتربيزات/الإعدادات/الشيفتات.
// ═══════════════════════════════════════════════════════════════════════════

class SyncService {
  final AppDatabase db;
  final String senderId;

  SyncService(this.db) : senderId = _generateSenderId();

  static String _generateSenderId() {
    final rnd = Random();
    return 'desktop_${DateTime.now().millisecondsSinceEpoch}_${rnd.nextInt(999999)}';
  }

  String? _shopId;
  final List<StreamSubscription> _subs = [];
  Timer? _tablesDebounce;
  Timer? _drinkTablesDebounce;
  Timer? _staticDebounce;
  Timer? _shiftsDebounce;

  bool get isRunning => _shopId != null;

  // ── دورة الحياة ──────────────────────────────────────────────────────────

  Future<void> start(String shopId) async {
    if (isRunning) await stop();
    _shopId = shopId;
    FirebaseService.setShopId(shopId);

    await _pullInitialState(shopId);
    _startListeners(shopId);
  }

  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _tablesDebounce?.cancel();
    _drinkTablesDebounce?.cancel();
    _staticDebounce?.cancel();
    _shiftsDebounce?.cancel();
    _shopId = null;
  }

  // ── سحب الحالة الأولية (زي pullAllData في الموبايل) ────────────────────

  Future<void> _pullInitialState(String shopId) async {
    final devicesRemote = await FirebaseService.pullDevicesState(shopId);
    if (devicesRemote != null && devicesRemote.isNotEmpty) {
      await _applyDevicesFromRemote(devicesRemote);
    }

    final tablesRemote = await FirebaseService.get(FirebaseService.tablesStatePath(shopId));
    if (tablesRemote is Map && tablesRemote['tables'] is List) {
      await _applyTablesFromRemote(
        (tablesRemote['tables'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    }

    final drinkTablesRemote = await FirebaseService.get(FirebaseService.drinkTablesStatePath(shopId));
    if (drinkTablesRemote is Map && drinkTablesRemote['drink_tables'] is List) {
      await _applyDrinkTablesFromRemote(
        (drinkTablesRemote['drink_tables'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    }

    final staticRemote = await FirebaseService.get(FirebaseService.staticDataPath(shopId));
    if (staticRemote is Map) {
      await _applyStaticFromRemote(Map<String, dynamic>.from(staticRemote));
    }

    final openShiftsRemote = await FirebaseService.getAllOpenShifts(shopId);
    if (openShiftsRemote.isNotEmpty) {
      await _applyOpenShiftsFromRemote(openShiftsRemote);
    }
  }

  // ── SSE Listeners ─────────────────────────────────────────────────────────

  void _startListeners(String shopId) {
    _subs.add(FirebaseService.listenToDevices(
      shopId,
      onData: (raw, devices) => _applyDevicesFromRemote(devices, singleIndex: raw['single_device_index'] as int?),
      onError: (_) {},
    ));

    _subs.add(FirebaseService.listenToTables(
      shopId,
      onData: (raw, tables) => _applyTablesFromRemote(tables),
      onError: (_) {},
    ));

    _subs.add(FirebaseService.listenToDrinkTables(
      shopId,
      senderId: senderId,
      onData: (raw, tables) =>
          _applyDrinkTablesFromRemote(tables, singleIndex: raw['single_drink_table_index'] as int?),
      onError: (_) {},
    ));

    _subs.add(FirebaseService.listenToStatic(
      shopId,
      senderId: senderId,
      onData: _applyStaticFromRemote,
      onError: (_) {},
    ));

    _subs.add(FirebaseService.listenToOpenShifts(
      shopId,
      senderId: senderId,
      onData: _applyOpenShiftsFromRemote,
      onError: (_) {},
    ));
  }

  // ── تطبيق تحديثات من الريموت على Drift ────────────────────────────────────

  Future<void> _applyDevicesFromRemote(List<Map<String, dynamic>> devices, {int? singleIndex}) async {
    await db.transaction(() async {
      if (singleIndex != null && devices.length == 1) {
        final existing = await (db.select(db.devices)..where((t) => t.deviceId.equals(singleIndex)))
            .getSingleOrNull();
        final companion = deviceFromJson(devices.first, singleIndex);
        await db.into(db.devices).insertOnConflictUpdate(
              existing != null ? companion.copyWith(sessionLogJson: Value(existing.sessionLogJson)) : companion,
            );
        return;
      }
      for (var i = 0; i < devices.length; i++) {
        final existing = await (db.select(db.devices)..where((t) => t.deviceId.equals(i))).getSingleOrNull();
        final companion = deviceFromJson(devices[i], i);
        await db.into(db.devices).insertOnConflictUpdate(
              existing != null && (jsonDecode(companion.sessionLogJson.value) as List).isEmpty
                  ? companion.copyWith(sessionLogJson: Value(existing.sessionLogJson))
                  : companion,
            );
      }
    });
  }

  Future<void> _applyTablesFromRemote(List<Map<String, dynamic>> tables) async {
    await db.transaction(() async {
      for (var i = 0; i < tables.length; i++) {
        await db.into(db.gameTables).insertOnConflictUpdate(gameTableFromJson(tables[i], i));
      }
    });
  }

  Future<void> _applyDrinkTablesFromRemote(List<Map<String, dynamic>> tables, {int? singleIndex}) async {
    await db.transaction(() async {
      if (singleIndex != null && tables.length == 1) {
        await db.into(db.drinkTables).insertOnConflictUpdate(drinkTableFromJson(tables.first, singleIndex));
        return;
      }
      for (var i = 0; i < tables.length; i++) {
        await db.into(db.drinkTables).insertOnConflictUpdate(drinkTableFromJson(tables[i], i));
      }
    });
  }

  Future<void> _applyStaticFromRemote(Map<String, dynamic> data) async {
    await db.transaction(() async {
      final prices = data['prices'];
      if (prices is Map) {
        for (final e in prices.entries) {
          await db.into(db.prices).insertOnConflictUpdate(
                PricesCompanion.insert(priceKey: e.key.toString(), amount: (e.value as num).toInt()),
              );
        }
      }

      await (db.update(db.appConfig)..where((t) => t.id.equals(0))).write(
        AppConfigCompanion(
          shopName: data['shop_name'] != null ? Value(data['shop_name'].toString()) : const Value.absent(),
          adminPasswordHash: data['admin_password_hash'] != null
              ? Value(data['admin_password_hash'].toString())
              : const Value.absent(),
          historyPasswordHash: data['history_password_hash'] != null
              ? Value(data['history_password_hash'].toString())
              : const Value.absent(),
          historyPasswordEnabled: data['history_password_enabled'] != null
              ? Value(data['history_password_enabled'] as bool)
              : const Value.absent(),
          matchEnabled: data['match_enabled'] != null ? Value(data['match_enabled'] as bool) : const Value.absent(),
          numDevices: data['num_devices'] != null ? Value((data['num_devices'] as num).toInt()) : const Value.absent(),
          rechargeEnabled:
              data['recharge_enabled'] != null ? Value(data['recharge_enabled'] as bool) : const Value.absent(),
          rechargeBalance: data['recharge_balance'] != null
              ? Value((data['recharge_balance'] as num).toInt())
              : const Value.absent(),
        ),
      );

      final cashiersRemote = data['cashiers'];
      if (cashiersRemote is List) {
        await db.delete(db.cashiers).go();
        for (final c in cashiersRemote) {
          final m = Map<String, dynamic>.from(c as Map);
          await db.into(db.cashiers).insert(
                CashiersCompanion.insert(
                  name: m['name']?.toString() ?? '',
                  passwordHash: m['hash']?.toString() ?? '',
                ),
              );
        }
      }

      final menuRemote = data['menu'];
      final buyPricesRemote = data['menu_buy_prices'];
      final itemCategoriesRemote = data['menu_item_categories'];
      if (menuRemote is Map) {
        for (final e in menuRemote.entries) {
          await db.into(db.menuItems).insertOnConflictUpdate(
                MenuItemsCompanion.insert(
                  itemName: e.key.toString(),
                  price: (e.value as num).toInt(),
                  buyPrice: Value(buyPricesRemote is Map ? (buyPricesRemote[e.key] as num?)?.toInt() : null),
                  categoryId: Value(itemCategoriesRemote is Map ? itemCategoriesRemote[e.key]?.toString() : null),
                ),
              );
        }
      }

      final buffetCategoriesRemote = data['buffet_categories'];
      if (buffetCategoriesRemote is List) {
        await db.delete(db.buffetCategories).go();
        for (final c in buffetCategoriesRemote) {
          final m = Map<String, dynamic>.from(c as Map);
          await db.into(db.buffetCategories).insertOnConflictUpdate(
                BuffetCategoriesCompanion.insert(
                  id: m['id']?.toString() ?? '',
                  name: m['name']?.toString() ?? '',
                  emoji: Value(m['emoji']?.toString() ?? '🍽'),
                  sortOrder: Value((m['sort_order'] as num?)?.toInt() ?? 0),
                ),
              );
        }
      }

      final inventoryRemote = data['inventory'];
      if (inventoryRemote is Map) {
        for (final e in inventoryRemote.entries) {
          await db.into(db.inventoryItems).insertOnConflictUpdate(
                InventoryItemsCompanion.insert(itemName: e.key.toString(), quantity: Value((e.value as num).toInt())),
              );
        }
      }
      final dailySummaryRemote = data['daily_inventory_summary'];
      if (dailySummaryRemote is Map) {
        for (final e in dailySummaryRemote.entries) {
          await db.into(db.dailyInventorySummary).insertOnConflictUpdate(
                DailyInventorySummaryCompanion.insert(
                  itemName: e.key.toString(),
                  quantitySold: Value((e.value as num).toInt()),
                ),
              );
        }
      }

      final debtsRemote = data['debts'];
      if (debtsRemote is List) {
        await db.delete(db.debts).go();
        for (final d in debtsRemote) {
          await db.into(db.debts).insert(debtFromJson(Map<String, dynamic>.from(d as Map)));
        }
      }

      final expensesRemote = data['expenses'];
      if (expensesRemote is List) {
        for (final e in expensesRemote) {
          await db.into(db.expenses).insertOnConflictUpdate(expenseFromJson(Map<String, dynamic>.from(e as Map)));
        }
      }
      final expenseCategoriesRemote = data['expense_categories'];
      if (expenseCategoriesRemote is List) {
        await db.delete(db.expenseCategories).go();
        for (var i = 0; i < expenseCategoriesRemote.length; i++) {
          await db.into(db.expenseCategories).insert(
                ExpenseCategoriesCompanion.insert(name: expenseCategoriesRemote[i].toString(), sortOrder: Value(i)),
              );
        }
      }

      final rechargeCardsRemote = data['recharge_cards'];
      if (rechargeCardsRemote is List) {
        await db.delete(db.rechargeCards).go();
        for (final c in rechargeCardsRemote) {
          final m = Map<String, dynamic>.from(c as Map);
          await db.into(db.rechargeCards).insert(
                RechargeCardsCompanion.insert(
                  name: m['name']?.toString() ?? '',
                  value: (m['value'] as num?)?.toInt() ?? 0,
                ),
              );
        }
      }
    });
  }

  Future<void> _applyOpenShiftsFromRemote(Map<String, dynamic> raw) async {
    await db.transaction(() async {
      final clean = Map<String, dynamic>.from(raw)..remove('_sender_id');
      for (final entry in clean.entries) {
        if (entry.value is! Map) continue;
        final shift = Map<String, dynamic>.from(entry.value as Map);
        final existing =
            await (db.select(db.openShifts)..where((t) => t.cashierName.equals(entry.key))).getSingleOrNull();
        await db.into(db.openShifts).insertOnConflictUpdate(
              OpenShiftsCompanion.insert(
                cashierName: entry.key,
                startTime: shift['start_time']?.toString() ?? DateTime.now().toIso8601String(),
                transactionsJson: Value(jsonEncode(shift['transactions'] ?? [])),
                isLocal: Value(existing?.isLocal ?? false),
              ),
            );
      }
    });
  }

  // ── دفع تحديثات محلية لـ Firebase (يتنادى من الـ repositories/providers) ──

  Future<void> pushDeviceImmediate(int deviceId) async {
    if (_shopId == null) return;
    final device = await (db.select(db.devices)..where((t) => t.deviceId.equals(deviceId))).getSingleOrNull();
    if (device == null) return;
    await FirebaseService.pushSingleDeviceState(_shopId!, deviceId, deviceToJson(device), senderId);
  }

  Future<void> pushAllDevicesImmediate() async {
    if (_shopId == null) return;
    final devices = await db.watchDevices().first;
    await FirebaseService.pushDevicesStateSlim(_shopId!, devices.map(deviceToJson).toList(), senderId);
  }

  Future<void> pushDrinkTableImmediate(int tableId) async {
    if (_shopId == null) return;
    final table = await (db.select(db.drinkTables)..where((t) => t.tableId.equals(tableId))).getSingleOrNull();
    if (table == null) return;
    await FirebaseService.pushSingleDrinkTable(_shopId!, tableId, drinkTableToJson(table), senderId);
  }

  Future<void> appendHistoryRecord(Map<String, dynamic> record) async {
    if (_shopId == null) return;
    await FirebaseService.appendSingleHistoryRecord(_shopId!, record);
  }

  void schedulePushTables() {
    _tablesDebounce?.cancel();
    _tablesDebounce = Timer(const Duration(milliseconds: 800), () async {
      if (_shopId == null) return;
      final tables = await db.watchTables().first;
      await FirebaseService.pushTablesState(_shopId!, tables.map(gameTableToJson).toList(), senderId);
    });
  }

  void schedulePushDrinkTablesState() {
    _drinkTablesDebounce?.cancel();
    _drinkTablesDebounce = Timer(const Duration(milliseconds: 800), () async {
      if (_shopId == null) return;
      final tables = await db.watchDrinkTables().first;
      await FirebaseService.pushDrinkTablesState(_shopId!, tables.map(drinkTableToJson).toList(), senderId);
    });
  }

  void schedulePushStatic() {
    _staticDebounce?.cancel();
    _staticDebounce = Timer(const Duration(milliseconds: 800), () async {
      if (_shopId == null) return;
      final bundle = await _buildStaticBundle();
      await FirebaseService.pushStaticData(_shopId!, bundle.toJson(), senderId);
    });
  }

  void schedulePushShiftsHistory() {
    _shiftsDebounce?.cancel();
    _shiftsDebounce = Timer(const Duration(milliseconds: 800), () async {
      if (_shopId == null) return;
      final shifts = await (db.select(db.shiftsHistory)).get();
      await FirebaseService.pushShiftsHistory(
        _shopId!,
        shifts
            .map((s) => shiftToJson(
                  cashierName: s.cashierName,
                  startTime: s.startTime,
                  endTime: s.endTime,
                  transactions: _decodeListPublic(s.transactionsJson),
                ))
            .toList(),
      );
    });
  }

  Future<void> pushTournamentsImmediate() async {
    if (_shopId == null) return;
    final rows = await db.select(db.tournaments).get();
    final list = rows
        .map((t) => {
              'id': t.id,
              'name': t.name,
              'game': t.game,
              'entry_fee': t.entryFee,
              'max_players': t.maxPlayers,
              'status': t.status,
              'players': jsonDecode(t.playersJson),
              'rounds': jsonDecode(t.roundsJson),
              'current_round': t.currentRound,
              'winner_id': t.winnerId,
            })
        .toList();
    await FirebaseService.pushTournaments(_shopId!, list);
  }

  Future<void> pushOpenShiftsImmediate() async {
    if (_shopId == null) return;
    final rows = await db.select(db.openShifts).get();
    final data = <String, dynamic>{
      for (final r in rows)
        r.cashierName: shiftToJson(
          cashierName: r.cashierName,
          startTime: r.startTime,
          transactions: _decodeListPublic(r.transactionsJson),
        ),
    };
    await FirebaseService.pushOpenShifts(_shopId!, data, senderId);
  }

  Future<StaticDataBundle> _buildStaticBundle() async {
    final config = await db.readConfigOnce();
    final prices = await db.select(db.prices).get();
    final menuItems = await db.select(db.menuItems).get();
    final buffetCats = await db.select(db.buffetCategories).get();
    final inventory = await db.select(db.inventoryItems).get();
    final dailySummary = await db.select(db.dailyInventorySummary).get();
    final cashiers = await db.select(db.cashiers).get();
    final debtsRows = await db.select(db.debts).get();
    final expensesRows = await db.select(db.expenses).get();
    final expenseCats = await db.select(db.expenseCategories).get();
    final rechargeCardsRows = await db.select(db.rechargeCards).get();

    return StaticDataBundle(
      prices: {for (final p in prices) p.priceKey: p.amount},
      menu: {for (final m in menuItems) m.itemName: m.price},
      menuItemCategories: {
        for (final m in menuItems)
          if (m.categoryId != null) m.itemName: m.categoryId!,
      },
      buffetCategories:
          buffetCats.map((c) => {'id': c.id, 'name': c.name, 'emoji': c.emoji, 'sort_order': c.sortOrder}).toList(),
      menuBuyPrices: {
        for (final m in menuItems)
          if (m.buyPrice != null) m.itemName: m.buyPrice!,
      },
      inventory: {for (final i in inventory) i.itemName: i.quantity},
      dailyInventorySummary: {for (final d in dailySummary) d.itemName: d.quantitySold},
      shopName: config.shopName,
      adminPasswordHash: config.adminPasswordHash,
      historyPasswordHash: config.historyPasswordHash,
      historyPasswordEnabled: config.historyPasswordEnabled,
      matchEnabled: config.matchEnabled,
      numDevices: config.numDevices,
      cashiers: cashiers.map((c) => {'name': c.name, 'hash': c.passwordHash}).toList(),
      debts: debtsRows.map(debtToJson).toList(),
      expenses: expensesRows.map(expenseToJson).toList(),
      expenseCategories: expenseCats.map((c) => c.name).toList(),
      rechargeEnabled: config.rechargeEnabled,
      rechargeBalance: config.rechargeBalance,
      rechargeCards: rechargeCardsRows.map((c) => {'name': c.name, 'value': c.value}).toList(),
    );
  }
}

List<Map<String, dynamic>> _decodeListPublic(String jsonStr) {
  try {
    final d = jsonDecode(jsonStr);
    if (d is List) return d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {}
  return [];
}
