import 'package:drift/drift.dart';
import '../local/database.dart';
import 'firebase_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SubscriptionService — منقول من _loadShopId/_checkSubscriptionOnline/
// activateShop في app_state.dart بتاع الموبايل.
//
// الفكرة: مفيش نظام HWID/تشفير منفصل للديسكتوب — بنستخدم بالظبط نفس نظام
// الموبايل: كود تفعيل (shopId) بيتوصل بيه المحل بعقدة subscription في
// Firebase ({active: bool, expires: ISO date, shop_name}), وبيتخزن محليًا
// (هنا في Drift بدل SharedPreferences) عشان التطبيق يشتغل حتى لو النت وقع،
// طول ما الاشتراك لسه ساري حسب آخر تاريخ انتهاء معروف.
// ═══════════════════════════════════════════════════════════════════════════

enum SubscriptionState { unknown, needsActivation, active, expired }

class SubscriptionResult {
  final SubscriptionState state;
  final String? errorMessage;
  SubscriptionResult(this.state, [this.errorMessage]);
}

class SubscriptionService {
  final AppDatabase db;
  SubscriptionService(this.db);

  /// يتنادى أول ما التطبيق يفتح — بيحاول يحمّل shopId المحفوظ ويتحقق من
  /// صلاحية الاشتراك محليًا الأول (offline-first)، وبعدين يتأكد أونلاين
  /// في الخلفية.
  Future<SubscriptionResult> bootstrap() async {
    final config = await db.readConfigOnce();
    final cache = await (db.select(db.subscriptionCache)
          ..where((t) => t.id.equals(0)))
        .getSingleOrNull();

    if (config.shopId == null || config.shopId!.isEmpty) {
      return SubscriptionResult(SubscriptionState.needsActivation);
    }

    FirebaseService.setShopId(config.shopId);

    final expiryStr = cache?.expiryDate;
    final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;

    if (expiry != null && DateTime.now().isBefore(expiry)) {
      // ✅ لسه ساري حسب آخر معرفة محليًا — يشتغل حتى من غير نت.
      // نتأكد أونلاين في الخلفية من غير ما نستنى (fire-and-forget).
      // ignore: unawaited_futures
      checkOnline(config.shopId!);
      return SubscriptionResult(SubscriptionState.active);
    } else if (expiry != null) {
      return SubscriptionResult(SubscriptionState.expired);
    }

    // مفيش كاش خالص — لازم نت أول مرة
    return checkOnline(config.shopId!);
  }

  /// يتحقق من Firebase مباشرة (بيحتاج نت) ويحدّث الكاش المحلي.
  Future<SubscriptionResult> checkOnline(String shopId) async {
    try {
      final sub = await FirebaseService.getSubscription(shopId);
      if (sub == null) {
        return SubscriptionResult(SubscriptionState.needsActivation, 'تعذر الوصول لبيانات الاشتراك');
      }
      final active = sub['active'] as bool? ?? false;
      final expiresStr = sub['expires'] as String?;
      final expiry = expiresStr != null ? DateTime.tryParse(expiresStr) : null;

      if (expiry != null) {
        await _saveExpiry(expiry);
      }

      if (!active) return SubscriptionResult(SubscriptionState.expired, 'المحل موقوف، تواصل مع المطور');
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        return SubscriptionResult(SubscriptionState.expired, 'انتهى الاشتراك، تواصل مع المطور للتجديد');
      }

      final shopNameFromFb = sub['shop_name'] as String?;
      if (shopNameFromFb != null && shopNameFromFb.isNotEmpty) {
        await (db.update(db.appConfig)..where((t) => t.id.equals(0)))
            .write(AppConfigCompanion(shopName: Value(shopNameFromFb)));
      }

      return SubscriptionResult(SubscriptionState.active);
    } catch (e) {
      // مفيش نت — نرجع لآخر حالة معروفة محليًا (offline grace)
      final cache = await (db.select(db.subscriptionCache)..where((t) => t.id.equals(0))).getSingleOrNull();
      final expiry = cache?.expiryDate != null ? DateTime.tryParse(cache!.expiryDate!) : null;
      if (expiry != null && DateTime.now().isBefore(expiry)) {
        return SubscriptionResult(SubscriptionState.active);
      }
      return SubscriptionResult(SubscriptionState.needsActivation, 'تعذر الاتصال بالسيرفر، تأكد من الإنترنت');
    }
  }

  /// تفعيل بكود جديد (شاشة activation) — لازم نت.
  Future<String?> activate(String code) async {
    final id = code.trim().toUpperCase();
    if (id.isEmpty) return '⚠️ اكتب كود التفعيل';
    try {
      final sub = await FirebaseService.getSubscription(id);
      if (sub == null) return '❌ كود غلط، تأكد من الكود وحاول تاني';
      final active = sub['active'] as bool? ?? false;
      if (!active) return '❌ هذا المحل موقوف، تواصل مع المطور';

      final expiresStr = sub['expires'] as String?;
      if (expiresStr != null) {
        final expiry = DateTime.tryParse(expiresStr);
        if (expiry != null) {
          if (DateTime.now().isAfter(expiry)) {
            final d = '${expiry.day}/${expiry.month}/${expiry.year}';
            return '❌ انتهى الاشتراك في $d، تواصل مع المطور للتجديد';
          }
          await _saveExpiry(expiry);
        }
      }

      FirebaseService.setShopId(id);
      final shopNameFromFb = sub['shop_name'] as String?;
      await (db.update(db.appConfig)..where((t) => t.id.equals(0))).write(
        AppConfigCompanion(
          shopId: Value(id),
          shopName: shopNameFromFb != null && shopNameFromFb.isNotEmpty
              ? Value(shopNameFromFb)
              : const Value.absent(),
        ),
      );
      return null; // null = نجاح
    } catch (e) {
      return '❌ تعذر الاتصال بالسيرفر، تأكد من الإنترنت وحاول تاني';
    }
  }

  Future<void> _saveExpiry(DateTime expiry) async {
    await db.into(db.subscriptionCache).insertOnConflictUpdate(
          SubscriptionCacheCompanion(
            id: const Value(0),
            isActivated: const Value(true),
            expiryDate: Value(expiry.toIso8601String()),
            lastCheckedAt: Value(DateTime.now().toIso8601String()),
          ),
        );
  }
}
