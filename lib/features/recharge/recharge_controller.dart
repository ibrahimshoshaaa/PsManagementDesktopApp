import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../providers/core_providers.dart';

final rechargeControllerProvider = Provider<RechargeController>((ref) => RechargeController(ref));

class RechargeController {
  final Ref ref;
  RechargeController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> addCard(String name, int value) async {
    await _db.into(_db.rechargeCards).insert(RechargeCardsCompanion.insert(name: name, value: value));
  }

  Future<void> removeCard(int rowId) async {
    await (_db.delete(_db.rechargeCards)..where((t) => t.rowId.equals(rowId))).go();
  }

  /// شحن رصيد (top_up) — بيزود الرصيد المتاح.
  Future<void> addBalance(double amount, String note, {required String cashier}) async {
    final config = await _db.readConfigOnce();
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0)))
        .write(AppConfigCompanion(rechargeBalance: Value(config.rechargeBalance + amount.round())));
    await _addTransaction(type: 'top_up', name: note, value: amount, cashier: cashier);
  }

  /// استخدام كارت/شحن حر — بيقل الرصيد المتاح، وبيتسجل في السجل زي الموبايل بالظبط.
  Future<void> redeem({required String type, required String name, required double value, required String cashier}) async {
    await _addTransaction(type: type, name: name, value: value, cashier: cashier);

    final config = await _db.readConfigOnce();
    await (_db.update(_db.appConfig)..where((t) => t.id.equals(0)))
        .write(AppConfigCompanion(rechargeBalance: Value(config.rechargeBalance - value.round())));

    await _db.into(_db.historyRecords).insert(
          HistoryRecordsCompanion.insert(
            name: name,
            deviceType: const Value('recharge'),
            total: value,
            timeCost: Value(value),
            buffetCost: const Value(0),
            ordersJson: const Value('{}'),
            cashier: Value(ref.read(sessionProvider).cashierName ?? 'أدمن'),
            date: DateTime.now().toString(),
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
  }

  Future<void> _addTransaction({required String type, required String name, required double value, required String cashier}) async {
    // ملاحظة: shape المعاملات هنا مطابق للموبايل (type/name/value/cashier/date)
    // ومتخزّنة محليًا في RechargeTransactions كـ JSON خام لحد ما نحتاج نستعلم
    // عليها بتفصيل أكتر.
    await _db.into(_db.rechargeTransactions).insert(
          RechargeTransactionsCompanion.insert(
            dataJson: jsonEncode({
              'type': type,
              'name': name,
              'value': value,
              'cashier': cashier,
              'date': DateTime.now().toString(),
            }),
          ),
        );
  }

  Future<void> clearTransactions() async {
    await _db.delete(_db.rechargeTransactions).go();
  }
}
