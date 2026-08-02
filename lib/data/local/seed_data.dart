import 'package:drift/drift.dart';
import 'database.dart';

// ═══════════════════════════════════════════════════════════════════════════
// بيانات افتراضية أول ما الداتابيز يتعمل — منسوخة بالظبط من AppState() في
// تطبيق الموبايل (مش من ملف بايثون)، عشان تثبيت جديد للديسكتوب يقدر يتوافق
// فورًا مع باسورد الأدمن الافتراضي بتاع الموبايل من غير ما حد يحتاج يعرف
// كلمة السر الأصلية (بنستخدم الـ hash الجاهز مباشرة زي ما هو).
// ═══════════════════════════════════════════════════════════════════════════

const _defaultAdminHash =
    '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92';
const _defaultCashierHash =
    'ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f';
const _defaultHistoryHash =
    'ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f';

Future<void> seedDefaults(AppDatabase db) async {
  await db.into(db.appConfig).insert(
        AppConfigCompanion.insert(
          id: const Value(0),
          shopName: const Value('Shosha PlayStation'),
          adminPasswordHash: _defaultAdminHash,
          historyPasswordHash: _defaultHistoryHash,
        ),
      );

  await db.into(db.cashiers).insert(
        CashiersCompanion.insert(
          name: 'كاشير 1',
          passwordHash: _defaultCashierHash,
        ),
      );

  // نفس prices الافتراضية بالظبط من app_state.dart
  const defaultPrices = {
    'ps4_normal': 25,
    'ps4_multi': 35,
    'ps5_normal': 40,
    'ps5_multi': 50,
    'match_ps4_normal': 10,
    'match_ps4_multi': 15,
    'match_ps5_normal': 15,
    'match_ps5_multi': 20,
    'ping_normal': 50,
    'billiard_normal': 40,
    'billiard_american': 50,
  };
  for (final entry in defaultPrices.entries) {
    await db.into(db.prices).insert(
          PricesCompanion.insert(priceKey: entry.key, amount: entry.value),
        );
  }

  // نفس BuffetCategory.defaults بالظبط
  const defaultCategories = [
    ('hot', 'سخن', '🔥', 0),
    ('cold', 'بارد', '❄️', 1),
    ('snack', 'سناكس', '🍟', 2),
    ('drink', 'مشروبات', '🥤', 3),
    ('other', 'أخرى', '🍽', 4),
  ];
  for (final c in defaultCategories) {
    await db.into(db.buffetCategories).insert(
          BuffetCategoriesCompanion.insert(
            id: c.$1,
            name: c.$2,
            emoji: Value(c.$3),
            sortOrder: Value(c.$4),
          ),
        );
  }

  // نفس expenseCategories الافتراضية بالظبط من app_state.dart
  const defaultExpenseCategories = ['إيجار', 'كهرباء', 'رواتب', 'صيانة', 'أخرى'];
  for (var i = 0; i < defaultExpenseCategories.length; i++) {
    await db.into(db.expenseCategories).insert(
          ExpenseCategoriesCompanion.insert(
            name: defaultExpenseCategories[i],
            sortOrder: Value(i),
          ),
        );
  }

  await db.into(db.subscriptionCache).insert(
        const SubscriptionCacheCompanion.insert(id: Value(0)),
      );
}
