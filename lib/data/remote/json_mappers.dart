import 'dart:convert';
import '../local/database.dart';

// ═══════════════════════════════════════════════════════════════════════════
// json_mappers — تحويل بين صفوف Drift المحلية وشكل الـ JSON اللي بيتزامن فعليًا
// مع Firebase (نفس شكل toJson/fromJson بتاعة الموبايل بالظبط).
//
// مهم: الهوية (device id / table index) في الموبايل هي "الترتيب في الـ array"
// مش حقل id مخزّن فعليًا (PSDevice.fromJson بياخد id كـ parameter من الفهرس،
// مش من الـ JSON نفسه) — فبنفس المنطق، deviceId/tableId عندنا في Drift هو
// رقم الفهرس (0-based) نفسه اللي هيتبعت كـ index في مصفوفة devices/tables.
// ═══════════════════════════════════════════════════════════════════════════

Map<String, dynamic> _decodeMap(String jsonStr) {
  try {
    final d = jsonDecode(jsonStr);
    if (d is Map) return Map<String, dynamic>.from(d);
  } catch (_) {}
  return {};
}

List<Map<String, dynamic>> _decodeList(String jsonStr) {
  try {
    final d = jsonDecode(jsonStr);
    if (d is List) return d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {}
  return [];
}

Map<String, int> _decodeIntMap(String jsonStr) {
  final m = _decodeMap(jsonStr);
  return m.map((k, v) => MapEntry(k, (v as num).toInt()));
}

// ─── Devices ─────────────────────────────────────────────────────────────

Map<String, dynamic> deviceToJson(DeviceRow d) => {
      'id': d.deviceId,
      'display_name': d.displayName,
      'mode': d.mode,
      'device_type': d.deviceType,
      'status': d.status,
      'start_time': d.startTime,
      'added_seconds': d.addedSeconds,
      'is_paused': d.isPaused,
      'pause_start_time': d.pauseStartTime,
      'orders': _decodeIntMap(d.ordersJson),
      'timer_alert_minutes': d.timerAlertMinutes,
      'is_countdown': d.isCountdown,
      'countdown_total_seconds': d.countdownTotalSeconds,
      'countdown_alert_sent': d.countdownAlertSent,
      'session_log': _decodeList(d.sessionLogJson),
    };

/// شكل "slim" بدون session_log — ده اللي بيتبعت في الـ realtime sync (نفس
/// pushDevicesStateSlim بتاعة الموبايل) عشان الحمل يفضل خفيف.
Map<String, dynamic> deviceToSlimJson(DeviceRow d) {
  final j = deviceToJson(d);
  j.remove('session_log');
  return j;
}

DevicesCompanion deviceFromJson(Map<String, dynamic> j, int id) {
  return DevicesCompanion.insert(
    deviceId: id,
    displayName: Value(j['display_name']?.toString() ?? 'PS $id'),
    deviceType: Value(j['device_type']?.toString() ?? 'ps4'),
    mode: Value(j['mode']?.toString() ?? 'normal'),
    status: Value(j['status']?.toString() ?? 'متاح'),
    startTime: Value(j['start_time'] as int?),
    addedSeconds: Value((j['added_seconds'] as num?)?.toInt() ?? 0),
    isPaused: Value(j['is_paused'] as bool? ?? false),
    pauseStartTime: Value(j['pause_start_time'] as int?),
    ordersJson: Value(jsonEncode(Map<String, dynamic>.from(j['orders'] as Map? ?? {}))),
    timerAlertMinutes: Value((j['timer_alert_minutes'] as num?)?.toInt()),
    isCountdown: Value(j['is_countdown'] as bool? ?? false),
    countdownTotalSeconds: Value((j['countdown_total_seconds'] as num?)?.toInt()),
    countdownAlertSent: Value(j['countdown_alert_sent'] as bool? ?? false),
    sessionLogJson: Value(jsonEncode(j['session_log'] ?? [])),
  );
}

// ─── Game tables ─────────────────────────────────────────────────────────

Map<String, dynamic> gameTableToJson(GameTableRow t) => {
      'name': t.name,
      'rate': t.rate,
      'table_type': t.tableType,
      'game_price': t.gamePrice,
      'start_time': t.startTime,
      'is_paused': t.isPaused,
      'pause_start_time': t.pauseStartTime,
      'orders': _decodeIntMap(t.ordersJson),
    };

GameTablesCompanion gameTableFromJson(Map<String, dynamic> j, int id) {
  return GameTablesCompanion.insert(
    tableId: id,
    name: j['name']?.toString() ?? 'تربيزة $id',
    tableType: Value(j['table_type']?.toString() ?? 'ping'),
    rate: Value((j['rate'] as num?)?.toInt() ?? 0),
    gamePrice: Value((j['game_price'] as num?)?.toInt() ?? 0),
    startTime: Value(j['start_time'] as int?),
    isPaused: Value(j['is_paused'] as bool? ?? false),
    pauseStartTime: Value(j['pause_start_time'] as int?),
    ordersJson: Value(jsonEncode(Map<String, dynamic>.from(j['orders'] as Map? ?? {}))),
  );
}

// ─── Drink tables ────────────────────────────────────────────────────────

Map<String, dynamic> drinkTableToJson(DrinkTableRow t) => {
      'name': t.name,
      'orders': _decodeIntMap(t.ordersJson),
    };

DrinkTablesCompanion drinkTableFromJson(Map<String, dynamic> j, int id) {
  return DrinkTablesCompanion.insert(
    tableId: id,
    name: j['name']?.toString() ?? 'مشروبات $id',
    ordersJson: Value(jsonEncode(Map<String, dynamic>.from(j['orders'] as Map? ?? {}))),
  );
}

// ─── Static data (prices/menu/inventory/settings/cashiers/debts/expenses...) ──
//
// ⚠️ الموبايل بيستخدم PATCH على عقدة static/ كلها مرة واحدة (مش أعمدة منفصلة)
// عشان منمسحش حقول تطبيقات تانية. بنبني نفس الـ Map الكبير ده من كذا جدول
// في Drift، ونطبّق العكس بالظبط.

class StaticDataBundle {
  final Map<String, int> prices;
  final Map<String, int> menu;
  final Map<String, String> menuItemCategories;
  final List<Map<String, dynamic>> buffetCategories;
  final Map<String, int> menuBuyPrices;
  final Map<String, int> inventory;
  final Map<String, int> dailyInventorySummary;
  final String shopName;
  final String adminPasswordHash;
  final String historyPasswordHash;
  final bool historyPasswordEnabled;
  final bool matchEnabled;
  final int numDevices;
  final List<Map<String, dynamic>> cashiers;
  final List<Map<String, dynamic>> debts;
  final List<Map<String, dynamic>> expenses;
  final List<String> expenseCategories;
  final bool rechargeEnabled;
  final int rechargeBalance;
  final List<Map<String, dynamic>> rechargeCards;

  StaticDataBundle({
    required this.prices,
    required this.menu,
    required this.menuItemCategories,
    required this.buffetCategories,
    required this.menuBuyPrices,
    required this.inventory,
    required this.dailyInventorySummary,
    required this.shopName,
    required this.adminPasswordHash,
    required this.historyPasswordHash,
    required this.historyPasswordEnabled,
    required this.matchEnabled,
    required this.numDevices,
    required this.cashiers,
    required this.debts,
    required this.expenses,
    required this.expenseCategories,
    required this.rechargeEnabled,
    required this.rechargeBalance,
    required this.rechargeCards,
  });

  Map<String, dynamic> toJson() => {
        'prices': prices,
        'menu': menu,
        'menu_item_categories': menuItemCategories,
        'buffet_categories': buffetCategories,
        'menu_buy_prices': menuBuyPrices,
        'inventory': inventory,
        'daily_inventory_summary': dailyInventorySummary,
        'shop_name': shopName,
        'admin_password_hash': adminPasswordHash,
        'history_password_hash': historyPasswordHash,
        'history_password_enabled': historyPasswordEnabled,
        'match_enabled': matchEnabled,
        'num_devices': numDevices,
        'cashiers': cashiers,
        'debts': debts,
        'expenses': expenses,
        'expense_categories': expenseCategories,
        'recharge_enabled': rechargeEnabled,
        'recharge_balance': rechargeBalance,
        'recharge_cards': rechargeCards,
      };
}

/// المديونية في الموبايل من غير id — بس array position. rowId المحلي بيتشال
/// قبل الإرسال.
Map<String, dynamic> debtToJson(DebtRow d) => {
      'name': d.name,
      'amount': d.amount,
      'date': d.date,
      'paid': d.paid,
      'note': d.note,
      'created_at': d.createdAt,
      'created_by': d.createdBy,
      'payment_history': _decodeList(d.paymentHistoryJson),
    };

DebtsCompanion debtFromJson(Map<String, dynamic> j) => DebtsCompanion.insert(
      name: j['name']?.toString() ?? '',
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      date: j['date']?.toString() ?? '',
      paid: Value(j['paid'] as bool? ?? false),
      note: Value(j['note']?.toString()),
      createdAt: j['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      createdBy: Value(j['created_by']?.toString() ?? ''),
      paymentHistoryJson: Value(jsonEncode(j['payment_history'] ?? [])),
    );

Map<String, dynamic> expenseToJson(ExpenseRow e) => {
      'id': e.id,
      'title': e.title,
      'amount': e.amount,
      'category': e.category,
      'date': e.date,
      'note': e.note,
      'added_by': e.addedBy,
      'created_at': e.createdAt,
      if (e.updatedAt != null) 'updated_at': e.updatedAt,
    };

ExpensesCompanion expenseFromJson(Map<String, dynamic> j) => ExpensesCompanion.insert(
      id: j['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: j['title']?.toString() ?? '',
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      category: j['category']?.toString() ?? '',
      date: j['date']?.toString() ?? '',
      note: Value(j['note']?.toString()),
      addedBy: Value(j['added_by']?.toString() ?? ''),
      createdAt: j['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: Value(j['updated_at']?.toString()),
    );

// ─── History records ─────────────────────────────────────────────────────

Map<String, dynamic> historyRecordToJson(HistoryRecordRow h) => {
      'name': h.name,
      'device_type': h.deviceType,
      'is_match': h.isMatch,
      'is_game': h.isGame,
      'total': h.total,
      'time_cost': h.timeCost,
      'buffet_cost': h.buffetCost,
      'elapsed_seconds': h.elapsedSeconds,
      'orders': _decodeIntMap(h.ordersJson),
      'date': h.date,
    };

HistoryRecordsCompanion historyRecordFromJson(Map<String, dynamic> j, {String? remoteKey}) =>
    HistoryRecordsCompanion.insert(
      remoteKey: Value(remoteKey),
      name: j['name']?.toString() ?? '',
      deviceType: Value(j['device_type']?.toString()),
      isMatch: Value(j['is_match'] as bool? ?? false),
      isGame: Value(j['is_game'] as bool? ?? false),
      total: (j['total'] as num?)?.toDouble() ?? 0,
      timeCost: Value((j['time_cost'] as num?)?.toDouble() ?? 0),
      buffetCost: Value((j['buffet_cost'] as num?)?.toDouble() ?? 0),
      elapsedSeconds: Value((j['elapsed_seconds'] as num?)?.toInt() ?? 0),
      ordersJson: Value(jsonEncode(Map<String, dynamic>.from(j['orders'] as Map? ?? {}))),
      date: j['date']?.toString() ?? DateTime.now().toString(),
      createdAt: DateTime.now().toIso8601String(),
    );

// ─── Shift records ───────────────────────────────────────────────────────

Map<String, dynamic> shiftToJson({
  required String cashierName,
  required String startTime,
  String? endTime,
  required List<Map<String, dynamic>> transactions,
}) =>
    {
      'cashier_name': cashierName,
      'start_time': startTime,
      'end_time': endTime,
      'transactions': transactions,
    };
