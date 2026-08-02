import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import '../data/local/database.dart';
import '../data/remote/sync_service.dart';
import '../data/remote/subscription_service.dart';
import '../data/remote/audit_log_service.dart';
import '../data/remote/firebase_service.dart';

/// قاعدة البيانات — instance واحدة طول عمر التطبيق.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(ref.watch(databaseProvider));
});

/// خدمة المزامنة — instance واحدة، بتتشغل (start) بعد التفعيل ونجاح تسجيل
/// الدخول، وبتتوقف (stop) لو حصل logout كامل من المحل (نادر).
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref.watch(databaseProvider));
  ref.onDispose(service.stop);
  return service;
});

// ── إعدادات المحل (stream) ─────────────────────────────────────────────────

final appConfigProvider = StreamProvider<AppConfigRow>((ref) {
  return ref.watch(databaseProvider).watchConfig();
});

// ── حالة الجلسة الحالية (مش متخزنة — بترجع صفر لما تقفل التطبيق، زي
//    self.user_role/self.current_cashier_name في نسخة بايثون) ─────────────

enum UserRole { none, admin, cashier }

class SessionState {
  final UserRole role;
  final String? cashierName;
  const SessionState({this.role = UserRole.none, this.cashierName});

  SessionState copyWith({UserRole? role, String? cashierName}) =>
      SessionState(role: role ?? this.role, cashierName: cashierName ?? this.cashierName);
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  void loginAsAdmin() {
    state = const SessionState(role: UserRole.admin);
    AuditLogService.configure(shopId: FirebaseService.currentShopId, cashierName: null, isAdmin: true);
    AuditLogService.log(action: AuditAction.login, actionDetails: 'دخول الأدمن');
  }

  void loginAsCashier(String name) {
    state = SessionState(role: UserRole.cashier, cashierName: name);
    AuditLogService.configure(shopId: FirebaseService.currentShopId, cashierName: name, isAdmin: false);
    AuditLogService.log(action: AuditAction.login, actionDetails: 'دخول الكاشير $name');
  }

  void logout() {
    AuditLogService.log(action: AuditAction.logout, actionDetails: 'تسجيل خروج');
    state = const SessionState();
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

// ── البيانات المباشرة (كل الشاشات بتسمع منها) ──────────────────────────────

final devicesStreamProvider = StreamProvider<List<DeviceRow>>((ref) {
  return ref.watch(databaseProvider).watchDevices();
});

final gameTablesStreamProvider = StreamProvider<List<GameTableRow>>((ref) {
  return ref.watch(databaseProvider).watchTables();
});

final drinkTablesStreamProvider = StreamProvider<List<DrinkTableRow>>((ref) {
  return ref.watch(databaseProvider).watchDrinkTables();
});

final pricesStreamProvider = StreamProvider<List<PriceRow>>((ref) {
  return ref.watch(databaseProvider).watchPrices();
});

final cashiersStreamProvider = StreamProvider<List<CashierRow>>((ref) {
  return ref.watch(databaseProvider).watchCashiers();
});

final menuItemsStreamProvider = StreamProvider<List<MenuItemRow>>((ref) {
  return ref.watch(databaseProvider).watchMenuItems();
});

final buffetCategoriesStreamProvider = StreamProvider<List<BuffetCategoryRow>>((ref) {
  return ref.watch(databaseProvider).watchBuffetCategories();
});

final inventoryStreamProvider = StreamProvider<List<InventoryItemRow>>((ref) {
  return ref.watch(databaseProvider).watchInventory();
});

final debtsStreamProvider = StreamProvider<List<DebtRow>>((ref) {
  return ref.watch(databaseProvider).watchDebts();
});

final expensesStreamProvider = StreamProvider<List<ExpenseRow>>((ref) {
  return ref.watch(databaseProvider).watchExpenses();
});

final historyStreamProvider = StreamProvider<List<HistoryRecordRow>>((ref) {
  return ref.watch(databaseProvider).watchHistory();
});

final openShiftsStreamProvider = StreamProvider<List<OpenShiftRow>>((ref) {
  return ref.watch(databaseProvider).watchOpenShifts();
});

final dailyArchivesStreamProvider = StreamProvider<List<DailyArchiveRow>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.dailyArchives)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
});

final tournamentsStreamProvider = StreamProvider<List<TournamentRow>>((ref) {
  return ref.watch(databaseProvider).select(ref.watch(databaseProvider).tournaments).watch();
});

final rechargeCardsStreamProvider = StreamProvider<List<RechargeCardRow>>((ref) {
  return ref.watch(databaseProvider).select(ref.watch(databaseProvider).rechargeCards).watch();
});

final rechargeTransactionsStreamProvider = StreamProvider<List<RechargeTransactionRow>>((ref) {
  return (ref.watch(databaseProvider).select(ref.watch(databaseProvider).rechargeTransactions)
        ..orderBy([(t) => OrderingTerm.desc(t.rowId)]))
      .watch();
});

/// عدد ثانية-بثانية — بيشغّل إعادة بناء أي widget بيحتاج يحدّث "الوقت المنقضي"
/// أو الفلوس الحية للأجهزة/التربيزات الشغالة (شوف core/utils/ticker.dart).
final tickerProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (i) => i);
});
