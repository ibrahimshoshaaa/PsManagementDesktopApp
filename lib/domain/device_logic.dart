import '../data/local/database.dart';

// ═══════════════════════════════════════════════════════════════════════════
// منطق العمل بتاع الجهاز — منقول حرفيًا من lib/models/device.dart (PSDevice)
// بتاع الموبايل. أي تعديل هنا لازم يتراجع مع نفس الملف في الموبايل عشان
// الحسابات (السعر، الوقت) تفضل مطابقة 100% بين التطبيقين.
// ═══════════════════════════════════════════════════════════════════════════

extension DeviceLogic on DeviceRow {
  bool get isRunning => startTime != null && !isPaused;
  bool get isActive => startTime != null;

  int get elapsedSeconds {
    if (startTime == null) return 0;
    if (isPaused && pauseStartTime != null) {
      return (pauseStartTime! - startTime!) + addedSeconds;
    }
    return (DateTime.now().millisecondsSinceEpoch ~/ 1000 - startTime!) + addedSeconds;
  }

  int get remainingSeconds {
    if (!isCountdown || countdownTotalSeconds == null) return 0;
    final remaining = countdownTotalSeconds! - elapsedSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  bool get countdownFinished =>
      isCountdown && countdownTotalSeconds != null && elapsedSeconds >= countdownTotalSeconds!;

  /// سعر الوقت — بيدور على مفتاح `${deviceType}_$mode` في جدول الأسعار
  /// (مثلاً ps4_normal / ps5_multi)، وبيرجع لسعر افتراضي لو المفتاح مش موجود.
  double calculateTimePrice(Map<String, int> prices) {
    if (startTime == null) return 0;
    final key = '${deviceType}_$mode';
    final rate = prices[key] ?? (deviceType == 'ps5' ? 35 : 25);
    return (elapsedSeconds / 3600) * rate;
  }

  /// سعر الماتش الثابت (منفصل عن سعر الساعة) — بيدور على `match_${type}_${mode}`.
  int matchPrice(Map<String, int> prices) {
    final key = 'match_${deviceType}_$mode';
    return prices[key] ?? prices['match_ps4_normal'] ?? 10;
  }

  double buffetPrice(Map<String, int> ordersDecoded, Map<String, int> menu) {
    double total = 0;
    ordersDecoded.forEach((item, qty) {
      total += qty * (menu[item] ?? 0);
    });
    return total;
  }

  /// نص المؤقت — عد تنازلي لو الجلسة بوقت محدد، أو عد تصاعدي عادي.
  String timerText() {
    final seconds = isCountdown && countdownTotalSeconds != null ? remainingSeconds : elapsedSeconds;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
