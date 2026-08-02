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
  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();
  IntColumn get pauseStartTime => integer().nullable()();
  TextColumn get ordersJson => text().withDefault(const Constant('{}'))();
  TextColumn get sessionLogJson => text().withDefault(const Constant('[]'))();

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
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  /// للاختبارات: بمرر اتصال جاهز (in-memory مثلاً) بدل ما يفتح ملف حقيقي.
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaults(this);
        },
        // لما تضيف جدول/عمود جديد لاحقًا: زوّد schemaVersion وضيف onUpgrade هنا.
      );

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
