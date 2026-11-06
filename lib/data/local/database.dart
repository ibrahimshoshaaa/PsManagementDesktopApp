import 'dart:convert';

import 'package:drift/drift.dart';
import 'connection.dart';
import 'seed_data.dart';

part 'database.g.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ⚠️ ملاحظة معمارية مهمة (تحديث بعد مراجعة كود الموبايل PsManagementMobileApp):
//
// الـ schema ده اتبنى مطابق لـ AppState + الموديلز بتاعة تطبيق الموبايل
// (المصدر الحقيقي الحالي للنظام) مش لملف بايثون الديسكتوب القديم، لأن الموبايل
// فيه مميزات مش موجودة في نسخة بايثون خالص:
//   - drink_tables (تربيزات مشروبات) بدل "الكافيه" في نسخة بايثون
//   - نظام شحن/رصيد (recharge)
//   - أقسام بوفيه بإيموجي (buffet_categories) + سعر شراء لكل صنف (buy price)
//   - طلبات عملاء (customer_orders) + سجل تدقيق (audit/activity logs)
//   - قفل شيفت بين الأجهزة (open_shifts) + باسورد منفصل لصفحة السجل
//   - "ماتش" (match) كنظام تسعير منفصل عن نظام البطولات بالبراكت
//
// الحقول اللي هنا مطابقة لأسماء المفاتيح في JSON اللي بيتزامن فعليًا مع
// Firebase (شوف firebase_service.dart) — أي تعديل هنا لازم يتراجع مع
// firebase_paths.dart / json mappers عشان التوافق يفضل قائم.
//
// حقول transient بس (زي timer_text, is_billing, saved_*) اتعمد إنها متبقاش
// أعمدة DB — هي Riverpod state جوه الـ UI بس، بتتحسب/تتصفر وقت التشغيل.
// ═══════════════════════════════════════════════════════════════════════════

@DataClassName('DeviceRow')
class Devices extends Table {
  IntColumn get deviceId => integer()();
  TextColumn get displayName => text()(); // json: display_name
  TextColumn get deviceType => text().withDefault(const Constant('ps4'))(); // ps4 | ps5
  TextColumn get mode => text().withDefault(const Constant('normal'))(); // normal | multi
  TextColumn get status => text().withDefault(const Constant('متاح'))();
  IntColumn get startTime => integer().nullable()(); // epoch seconds
  IntColumn get addedSeconds => integer().withDefault(const Constant(0))();
  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();
  IntColumn get pauseStartTime => integer().nullable()();
  TextColumn get ordersJson => text().withDefault(const Constant('{}'))();
  IntColumn get timerAlertMinutes => integer().nullable()(); // json: timer_alert_minutes
  BoolColumn get isCountdown => boolean().withDefault(const Constant(false))();
  IntColumn get countdownTotalSeconds => integer().nullable()();
  BoolColumn get countdownAlertSent => boolean().withDefault(const Constant(false))();
  TextColumn get sessionLogJson => text().withDefault(const Constant('[]'))();

  RealColumn get settledTimeCost => real().withDefault(const Constant(0))();
  IntColumn get segmentStartSeconds => integer().withDefault(const Constant(0))();
  IntColumn get localCustomerId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {deviceId};
}

/// تربيزات الجيمات (بلياردو / تنس طاولة...) — عندها سعر بالساعة (rate)
/// وممكن كمان سعر ثابت للعبة الواحدة (gamePrice) لو النوع بيتحاسب بالجيم.
@DataClassName('GameTableRow')
class GameTables extends Table {
  IntColumn get tableId => integer()();
  TextColumn get name => text()();
  TextColumn get tableType => text().withDefault(const Constant('ping'))(); // json: table_type
  IntColumn get rate => integer().withDefault(const Constant(0))(); // سعر الساعة
  IntColumn get gamePrice => integer().withDefault(const Constant(0))(); // json: game_price
  IntColumn get startTime => integer().nullable()();
  IntColumn get addedSeconds => integer().withDefault(const Constant(0))();
  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();
  IntColumn get pauseStartTime => integer().nullable()();
  TextColumn get ordersJson => text().withDefault(const Constant('{}'))();
  TextColumn get sessionLogJson => text().withDefault(const Constant('[]'))();

  IntColumn get countdownTotalSeconds => integer().nullable()();
  IntColumn get localCustomerId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {tableId};
}

/// تربيزات المشروبات (drink_tables) — بسيطة: بس أوردرات وتحاسب، من غير تايمر.
@DataClassName('DrinkTableRow')
class DrinkTables extends Table {
  IntColumn get tableId => integer()();
  TextColumn get name => text()();
  TextColumn get ordersJson => text().withDefault(const Constant('{}'))();
  TextColumn get sessionLogJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {tableId};
}

/// صف واحد بس (id = 0) — إعدادات المحل العامة ومفاتيح الربط بالسحابة.
@DataClassName('AppConfigRow')
class AppConfig extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();

  /// معرف المحل في Firebase (shops/{shopId}/...) — بيتحدد من نظام التفعيل/الاشتراك.
  TextColumn get shopId => text().nullable()();

  TextColumn get shopName => text().withDefault(const Constant('بلايستيشن الحريفة'))();
  TextColumn get adminPasswordHash => text()();
  TextColumn get historyPasswordHash => text()();
  BoolColumn get historyPasswordEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get matchEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get numDevices => integer().withDefault(const Constant(0))();

  BoolColumn get gameTablesEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get drinkTablesEnabled => boolean().withDefault(const Constant(true))();

  BoolColumn get rechargeEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get rechargeBalance => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// أسعار الساعة/الماتش لكل نوع جهاز، بمفاتيح زي ps4_normal / match_ps5_multi.
@DataClassName('PriceRow')
class Prices extends Table {
  TextColumn get priceKey => text()();
  IntColumn get amount => integer()();

  @override
  Set<Column> get primaryKey => {priceKey};
}

@DataClassName('CashierRow')
class Cashiers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get passwordHash => text()(); // json key: hash

  @override
  List<Set<Column>> get uniqueKeys => [
        {name}
      ];
}

/// أقسام البوفيه بإيموجي (buffet_categories) — id ثابت (hot/cold/snack...)
@DataClassName('BuffetCategoryRow')
class BuffetCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get emoji => text().withDefault(const Constant('🍽'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// أصناف المنيو — بيربط كل صنف بقسم بوفيه، ومعاه سعر البيع وسعر الشراء
/// (لحساب هامش الربح — menu_buy_prices في الموبايل).
@DataClassName('MenuItemRow')
class MenuItems extends Table {
  TextColumn get itemName => text()();
  IntColumn get price => integer()(); // سعر البيع
  IntColumn get buyPrice => integer().nullable()(); // سعر الشراء (للربح)
  TextColumn get categoryId => text().nullable()(); // BuffetCategories.id

  @override
  Set<Column> get primaryKey => {itemName};
}

@DataClassName('InventoryItemRow')
class InventoryItems extends Table {
  TextColumn get itemName => text()();
  IntColumn get quantity => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {itemName};
}

/// كمية كل صنف اتباعت اليوم (daily_inventory_summary) — بيتصفر عند الأرشفة.
@DataClassName('DailyInventorySummaryRow')
class DailyInventorySummary extends Table {
  TextColumn get itemName => text()();
  IntColumn get quantitySold => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {itemName};
}

@DataClassName('ExpenseCategoryRow')
class ExpenseCategories extends Table {
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {name};
}

/// ⚠️ الموبايل مش بيدي المديونيات id — بيتعامل بالـ index جوه الـ list.
/// rowId هنا محلي بس (للاستعلام في SQLite)؛ عند المزامنة مع Firebase
/// بيتبعت array من غير أي id (شوف json_mappers.dart).
@DataClassName('DebtRow')
class Debts extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  TextColumn get date => text()();
  BoolColumn get paid => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text()(); // json: created_at
  TextColumn get createdBy => text().withDefault(const Constant(''))(); // json: created_by
  TextColumn get paymentHistoryJson => text().withDefault(const Constant('[]'))(); // json: payment_history
}

/// المصروفات — عندها id حقيقي (نص، مش رقم) زي ما الموبايل بيعمل بالظبط
/// (DateTime.now().millisecondsSinceEpoch.toString()).
@DataClassName('ExpenseRow')
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get category => text()();
  TextColumn get date => text()(); // "d/M/yyyy"
  TextColumn get note => text().nullable()();
  TextColumn get addedBy => text().withDefault(const Constant(''))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// البطولات (بالبراكت) — منفصلة تمامًا عن نظام "الماتش" (match_enabled).
/// بتتحمل on-demand بس (شوف firebase_rest_service.dart) فمش هتتحمل تلقائي.
@DataClassName('TournamentRow')
class Tournaments extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get game => text().withDefault(const Constant(''))();
  IntColumn get entryFee => integer().withDefault(const Constant(0))();
  IntColumn get maxPlayers => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('تسجيل'))();
  TextColumn get playersJson => text().withDefault(const Constant('[]'))();
  TextColumn get roundsJson => text().withDefault(const Constant('[]'))();
  IntColumn get currentRound => integer().withDefault(const Constant(0))();
  TextColumn get winnerId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// سجلات الشيفت الحالي — الحقول دي مؤكدة من shift_service.dart
/// (اللي بيقرا منها الإحصائيات: time_cost, buffet_cost, is_match, is_game...).
@DataClassName('HistoryRecordRow')
class HistoryRecords extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  IntColumn get localCustomerId => integer().nullable()();
  TextColumn get cashier => text().nullable()();
  TextColumn get remoteKey => text().nullable()(); // مفتاح الـ push في Firebase لو اتزامن
  TextColumn get name => text()();
  TextColumn get deviceType => text().nullable()(); // json: device_type ('drink_table' لتربيزات المشروبات)
  BoolColumn get isMatch => boolean().withDefault(const Constant(false))();
  BoolColumn get isGame => boolean().withDefault(const Constant(false))();
  RealColumn get total => real()();
  RealColumn get timeCost => real().withDefault(const Constant(0))();
  RealColumn get buffetCost => real().withDefault(const Constant(0))();
  IntColumn get elapsedSeconds => integer().withDefault(const Constant(0))();
  TextColumn get ordersJson => text().withDefault(const Constant('{}'))();
  TextColumn get date => text()();
  TextColumn get createdAt => text()();
}

/// كروت الشحن — name + value مؤكدين من الكود؛ باقي الحقول (لو اتضافت لاحقًا)
/// هتتحط هنا كمان.
@DataClassName('RechargeCardRow')
class RechargeCards extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get value => integer()();
}

/// ⚠️ شكل الحركات (recharge_transactions) لسه مش متأكد منه 100% من كود
/// الموبايل اللي راجعناه — الجدول ده placeholder بشكل عام (JSON خام) لحد
/// ما نبني شاشة الشحن ونتأكد من الحقول بالظبط.
@DataClassName('RechargeTransactionRow')
class RechargeTransactions extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get dataJson => text()();
}

/// ⚠️ طلبات العملاء (customer_orders) — لقينا المسار في Firebase بس من غير
/// استخدام فعلي واضح في app_state.dart اللي شفناه؛ placeholder لحد ما نتأكد.
@DataClassName('CustomerOrderRow')
class CustomerOrders extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get remoteKey => text().nullable()();
  TextColumn get dataJson => text()();
}

/// الشيفتات المقفولة (سجل) — مطابق لـ ShiftRecord.toJson() في الموبايل.
@DataClassName('ShiftHistoryRow')
class ShiftsHistory extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get cashierName => text()();
  TextColumn get startTime => text()(); // ISO8601
  TextColumn get endTime => text().nullable()();
  TextColumn get transactionsJson => text().withDefault(const Constant('[]'))();
}

/// الشيفتات المفتوحة حاليًا (لأي كاشير على أي جهاز) — بتُستخدم لمنع نفس
/// الكاشير يفتح شيفت في جهازين، ولإظهار "الشيفت مقفول من كاشير تاني".
@DataClassName('OpenShiftRow')
class OpenShifts extends Table {
  TextColumn get cashierName => text()();
  TextColumn get startTime => text()();
  TextColumn get transactionsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get isLocal => boolean().withDefault(const Constant(false))(); // إحنا اللي فتحناه من الجهاز ده

  @override
  Set<Column> get primaryKey => {cashierName};
}

@DataClassName('DailyArchiveRow')
class DailyArchives extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get date => text()();
  RealColumn get totalTime => real()();
  RealColumn get totalBuffet => real()();
  RealColumn get totalOverall => real()();
  TextColumn get recordsJson => text()();
}

@DataClassName('YearlyArchiveRow')
class YearlyArchives extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get dataJson => text()();
}

/// كاش محلي لبيانات الاشتراك/التفعيل — عشان لو النت وقع نفضل عارفين آخر حالة
/// معروفة (زي الـ offline-capable activation في الموبايل).
@DataClassName('SubscriptionCacheRow')
class SubscriptionCache extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  BoolColumn get isActivated => boolean().withDefault(const Constant(false))();
  TextColumn get expiryDate => text().nullable()();
  TextColumn get lastCheckedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalCustomer')
class LocalCustomers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().unique()();
  IntColumn get visits => integer().withDefault(const Constant(0))();
  RealColumn get totalSpent => real().withDefault(const Constant(0))();
  TextColumn get lastVisit => text().withDefault(const Constant(''))();
}

class LocalAuditEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entryJson => text()();
}

class DesktopLicenses extends Table {
  IntColumn get id => integer()();
  TextColumn get token => text()();
  IntColumn get lastSeenUtcMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Devices,
  GameTables,
  DrinkTables,
  AppConfig,
  Prices,
  Cashiers,
  BuffetCategories,
  MenuItems,
  InventoryItems,
  DailyInventorySummary,
  ExpenseCategories,
  Debts,
  Expenses,
  Tournaments,
  HistoryRecords,
  RechargeCards,
  RechargeTransactions,
  CustomerOrders,
  ShiftsHistory,
  OpenShifts,
  DailyArchives,
  YearlyArchives,
  SubscriptionCache,
  LocalCustomers,
  LocalAuditEvents,
  DesktopLicenses,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  /// للاختبارات: بمرر اتصال جاهز (in-memory مثلاً) بدل ما يفتح ملف حقيقي.
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaults(this);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(historyRecords, historyRecords.cashier);
          if (from < 3) {
            await m.createTable(localCustomers);
            await m.createTable(localAuditEvents);
          }
          if (from < 4) await m.createTable(desktopLicenses);
          if (from < 5) {
            await m.addColumn(devices, devices.settledTimeCost);
            await m.addColumn(devices, devices.segmentStartSeconds);
            await m.addColumn(devices, devices.localCustomerId);
            await m.addColumn(historyRecords, historyRecords.localCustomerId);
          }
          if (from < 6) {
            await m.addColumn(gameTables, gameTables.countdownTotalSeconds);
            await m.addColumn(gameTables, gameTables.localCustomerId);
          }
          if (from < 7) {
            await m.addColumn(appConfig, appConfig.gameTablesEnabled);
            await m.addColumn(appConfig, appConfig.drinkTablesEnabled);
          }
        },
      );

  Future<void> recordCustomerVisit(int? id, double total, String date) async {
    if (id == null) return;
    final customer = await (select(localCustomers)..where((row) => row.id.equals(id))).getSingleOrNull();
    if (customer == null) return;
    await (update(localCustomers)..where((row) => row.id.equals(id))).write(
      LocalCustomersCompanion(
        visits: Value(customer.visits + 1), totalSpent: Value(customer.totalSpent + total), lastVisit: Value(date),
      ),
    );
  }

  /// The caller saves the resulting quantities in the same transaction.
  Future<Map<String, int>> changeBuffetOrders(String ordersJson, Map<String, int> changes) async {
    final orders = Map<String, int>.from(jsonDecode(ordersJson) as Map);
    final additions = changes.entries.where((entry) => entry.value > 0).toList();
    if (additions.isNotEmpty) {
      final stock = {for (final row in await select(inventoryItems).get()) row.itemName: row.quantity};
      final menu = {for (final row in await select(menuItems).get()) row.itemName};
      final reserved = <String, int>{};
      if (additions.any((entry) => stock.containsKey(entry.key))) {
        final openOrders = [
          for (final row in await select(devices).get()) row.ordersJson,
          for (final row in await select(gameTables).get()) row.ordersJson,
          for (final row in await select(drinkTables).get()) row.ordersJson,
        ];
        for (final json in openOrders) {
          final lines = Map<String, int>.from(jsonDecode(json) as Map);
          for (final entry in lines.entries) {
            reserved.update(entry.key, (count) => count + entry.value, ifAbsent: () => entry.value);
          }
        }
      }
      for (final addition in additions) {
        final name = addition.key;
        if (!menu.contains(name)) throw StateError('الصنف $name مش موجود في المنيو.');
        final quantity = stock[name];
        if (quantity != null && (reserved[name] ?? 0) + addition.value > quantity) {
          throw StateError('المخزون المتاح من $name أقل من الكمية المطلوبة.');
        }
      }
    }
    for (final change in changes.entries) {
      final quantity = (orders[change.key] ?? 0) + change.value;
      if (quantity > 0) {
        orders[change.key] = quantity;
      } else {
        orders.remove(change.key);
      }
    }
    return orders;
  }

  /// Called inside the same transaction as receipt creation and session reset.
  Future<void> deductSoldItems(Map<String, int> orders) async {
    for (final entry in orders.entries) {
      if (entry.value <= 0) continue;
      final row = await (select(inventoryItems)
            ..where((item) => item.itemName.equals(entry.key)))
          .getSingleOrNull();
      if (row == null) continue;
      final remaining = row.quantity - entry.value;
      await (update(inventoryItems)..where((item) => item.itemName.equals(entry.key)))
          .write(InventoryItemsCompanion(quantity: Value(remaining < 0 ? 0 : remaining)));
    }
  }

  // ── Streams جاهزة هيتم استخدامها من الـ providers ──

  Stream<AppConfigRow> watchConfig() =>
      (select(appConfig)..where((t) => t.id.equals(0))).watchSingle();

  Future<AppConfigRow> readConfigOnce() =>
      (select(appConfig)..where((t) => t.id.equals(0))).getSingle();

  Stream<List<DeviceRow>> watchDevices() =>
      (select(devices)..orderBy([(t) => OrderingTerm.asc(t.deviceId)])).watch();

  Stream<List<GameTableRow>> watchTables() =>
      (select(gameTables)..orderBy([(t) => OrderingTerm.asc(t.tableId)])).watch();

  Stream<List<DrinkTableRow>> watchDrinkTables() =>
      (select(drinkTables)..orderBy([(t) => OrderingTerm.asc(t.tableId)])).watch();

  Stream<List<PriceRow>> watchPrices() => select(prices).watch();

  Stream<List<CashierRow>> watchCashiers() => select(cashiers).watch();

  Stream<List<BuffetCategoryRow>> watchBuffetCategories() =>
      (select(buffetCategories)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();

  Stream<List<MenuItemRow>> watchMenuItems() => select(menuItems).watch();

  Stream<List<InventoryItemRow>> watchInventory() => select(inventoryItems).watch();

  Stream<List<DebtRow>> watchDebts() =>
      (select(debts)..orderBy([(t) => OrderingTerm.desc(t.rowId)])).watch();

  Stream<List<ExpenseRow>> watchExpenses() =>
      (select(expenses)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Stream<List<HistoryRecordRow>> watchHistory() =>
      (select(historyRecords)..orderBy([(t) => OrderingTerm.desc(t.rowId)])).watch();

  Stream<List<OpenShiftRow>> watchOpenShifts() => select(openShifts).watch();
}
