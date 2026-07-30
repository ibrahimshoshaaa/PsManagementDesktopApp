import '../local/database.dart';
import 'firebase_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// AuditLogService — منقول حرفيًا من lib/services/audit_log_service.dart
// بتاع الموبايل. المسار: shops/{shopId}/activity_logs/{pushKey}
// ═══════════════════════════════════════════════════════════════════════════

enum AuditAction {
  deviceStart,
  deviceStop,
  deviceCancel,
  devicePause,
  deviceResume,
  deviceAddTime,
  deviceTransfer,
  deviceTimerSet,
  deviceModeChange,
  buffetItemAdded,
  buffetItemRemoved,
  tableStart,
  tableStop,
  tableCancel,
  tablePause,
  tableResume,
  tableGameRecord,
  tableOrderAdded,
  tableOrderRemoved,
  drinkTableOrderAdded,
  drinkTableOrderRemoved,
  drinkTableCheckout,
  drinkTableTransfer,
  debtAdded,
  debtPaid,
  debtPartialPaid,
  debtAmountAdded,
  debtDeleted,
  dayArchived,
  yearlyArchiveSaved,
  shiftStarted,
  shiftEnded,
  pricesUpdated,
  menuItemAdded,
  menuItemUpdated,
  menuItemDeleted,
  deviceAdded,
  deviceRemoved,
  deviceRenamed,
  tableAdded,
  tableRemoved,
  drinkTableAdded,
  drinkTableRemoved,
  passwordChanged,
  cashierAdded,
  cashierRemoved,
  shopNameChanged,
  matchToggled,
  inventoryUpdated,
  tournamentCreated,
  tournamentDeleted,
  tournamentPlayerAdded,
  tournamentPlayerRemoved,
  tournamentMatchResult,
  tournamentEnded,
  expenseAdded,
  expenseDeleted,
  expenseUpdated,
  matchRecorded,
  login,
  logout,
}

class AuditLogService {
  static String? _shopId;
  static String? _cashierName;
  static bool _isAdmin = false;

  static void configure({required String? shopId, required String? cashierName, required bool isAdmin}) {
    _shopId = shopId;
    _cashierName = cashierName;
    _isAdmin = isAdmin;
  }

  static Future<void> log({required AuditAction action, required String actionDetails, Map<String, dynamic>? extra}) async {
    if (_shopId == null) return;
    try {
      final entry = {
        'action': action.name,
        'action_details': actionDetails,
        'timestamp': DateTime.now().toIso8601String(),
        'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
        'cashier_name': _cashierName ?? (_isAdmin ? 'أدمن' : 'غير محدد'),
        'cashier_id': _cashierName ?? (_isAdmin ? '__admin__' : '__unknown__'),
        'role': _isAdmin ? 'admin' : 'cashier',
        if (extra != null) ...extra,
      };
      // fire-and-forget — ما بنستناش عشان ما نبطئش الـ UI
      FirebaseService.push('shops/$_shopId/activity_logs', entry);
    } catch (_) {}
  }

  static Future<void> logDevice({required AuditAction action, required String deviceName, String? deviceType, String? extra}) =>
      log(
        action: action,
        actionDetails: _deviceMsg(action, deviceName, extra),
        extra: {'device_name': deviceName, if (deviceType != null) 'device_type': deviceType},
      );

  static Future<void> logTable({required AuditAction action, required String tableName, String? extra}) => log(
        action: action,
        actionDetails: _tableMsg(action, tableName, extra),
        extra: {'table_name': tableName},
      );

  static Future<void> logDebt({required AuditAction action, required String personName, required double amount}) => log(
        action: action,
        actionDetails: _debtMsg(action, personName, amount),
        extra: {'person_name': personName, 'amount': amount},
      );

  static String _deviceMsg(AuditAction a, String name, String? extra) {
    switch (a) {
      case AuditAction.deviceStart:
        return 'بدأ تشغيل الجهاز "$name"${extra != null ? " ($extra)" : ""}';
      case AuditAction.deviceStop:
        return 'أنهى جلسة الجهاز "$name"${extra != null ? " | $extra" : ""}';
      case AuditAction.deviceCancel:
        return 'ألغى جلسة الجهاز "$name" بدون حساب';
      case AuditAction.devicePause:
        return 'وقّف مؤقتاً الجهاز "$name"';
      case AuditAction.deviceResume:
        return 'استأنف الجهاز "$name"';
      case AuditAction.deviceAddTime:
        return 'عدّل وقت الجهاز "$name"${extra != null ? ": $extra" : ""}';
      case AuditAction.deviceTransfer:
        return 'نقل جلسة الجهاز "$name"${extra != null ? " → $extra" : ""}';
      case AuditAction.buffetItemAdded:
        return 'أضاف "${extra ?? "صنف"}" لبوفيه "$name"';
      case AuditAction.buffetItemRemoved:
        return 'أزال "${extra ?? "صنف"}" من بوفيه "$name"';
      default:
        return '$name — ${a.name}';
    }
  }

  static String _tableMsg(AuditAction a, String name, String? extra) {
    switch (a) {
      case AuditAction.tableStart:
        return 'بدأ تربيزة "$name"';
      case AuditAction.tableStop:
        return 'أنهى تربيزة "$name"${extra != null ? " | $extra" : ""}';
      case AuditAction.tableCancel:
        return 'ألغى تربيزة "$name" بدون حساب';
      case AuditAction.tablePause:
        return 'وقّف مؤقتاً تربيزة "$name"';
      case AuditAction.tableResume:
        return 'استأنف تربيزة "$name"';
      case AuditAction.tableGameRecord:
        return 'سجّل جيم في "$name"${extra != null ? " ($extra)" : ""}';
      case AuditAction.drinkTableCheckout:
        return 'حاسب تربيزة مشروبات "$name"${extra != null ? " | $extra" : ""}';
      case AuditAction.tableOrderAdded:
        return 'أضاف "${extra ?? "صنف"}" لبوفيه تربيزة "$name"';
      case AuditAction.tableOrderRemoved:
        return 'أزال "${extra ?? "صنف"}" من بوفيه تربيزة "$name"';
      default:
        return '$name — ${a.name}';
    }
  }

  static String _debtMsg(AuditAction a, String name, double amount) {
    switch (a) {
      case AuditAction.debtAdded:
        return 'أضاف مديونية لـ "$name" بمبلغ ${amount.toStringAsFixed(1)} ج';
      case AuditAction.debtPaid:
        return 'سجّل تسديد كامل من "$name" بمبلغ ${amount.toStringAsFixed(1)} ج';
      case AuditAction.debtPartialPaid:
        return 'سجّل تسديد جزئي من "$name" بمبلغ ${amount.toStringAsFixed(1)} ج';
      case AuditAction.debtAmountAdded:
        return 'أضاف ${amount.toStringAsFixed(1)} ج لمديونية "$name"';
      case AuditAction.debtDeleted:
        return 'حذف مديونية "$name"';
      default:
        return '"$name" — ${a.name}';
    }
  }
}

/// جلب سجل التدقيق للعرض (on-demand، أدمن بس) — الموبايل مش عنده listener
/// دايم عليه، بيتحمل وقت فتح الشاشة زي البطولات بالظبط.
Future<List<Map<String, dynamic>>> fetchAuditLogs(String shopId, {int limit = 100}) async {
  try {
    final data = await FirebaseService.get('${FirebaseService.activityLogsPath(shopId)}');
    if (data == null || data is! Map) return [];
    final entries = data.entries.map((e) => Map<String, dynamic>.from(e.value as Map)).toList();
    entries.sort((a, b) => (b['timestamp_ms'] as num? ?? 0).compareTo(a['timestamp_ms'] as num? ?? 0));
    return entries.take(limit).toList();
  } catch (_) {
    return [];
  }
}
