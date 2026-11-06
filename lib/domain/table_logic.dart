import '../data/local/database.dart';

// ═══════════════════════════════════════════════════════════════════════════
// منطق العمل بتاع تربيزات الجيمات — نفس فكرة device_logic.dart، بس التربيزة
// عندها سعرين مختلفين مخزّنين: rate (بالساعة) و game_price (سعر ثابت للعبة
// الواحدة، مفيد لتنس الطاولة/البلياردو اللي بيتحاسب بالجيم مش بالوقت).
// ═══════════════════════════════════════════════════════════════════════════

extension TableLogic on GameTableRow {
  bool get isActive => startTime != null;
  bool get isRunning => startTime != null && !isPaused;

  int get elapsedSeconds {
    if (startTime == null) return 0;
    final now = isPaused && pauseStartTime != null
        ? pauseStartTime! : DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsed = now - startTime! + addedSeconds;
    return elapsed < 0 ? 0 : elapsed;
  }

  /// تكلفة الوقت (لو بيتحاسب بالساعة).
  double get hourlyTimeCost => (elapsedSeconds / 3600) * rate;

  double buffetPrice(Map<String, int> ordersDecoded, Map<String, int> menu) {
    double total = 0;
    ordersDecoded.forEach((item, qty) {
      total += qty * (menu[item] ?? 0);
    });
    return total;
  }

  bool get countdownFinished => isActive && countdownTotalSeconds != null &&
      elapsedSeconds >= countdownTotalSeconds!;

  String timerText() {
    final elapsed = elapsedSeconds;
    final remaining = countdownTotalSeconds == null ? elapsed : countdownTotalSeconds! - elapsed;
    final s = remaining < 0 ? 0 : remaining;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
