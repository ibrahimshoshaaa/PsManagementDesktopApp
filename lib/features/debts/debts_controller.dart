import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/remote/audit_log_service.dart';
import '../../providers/core_providers.dart';

final debtsControllerProvider = Provider<DebtsController>((ref) => DebtsController(ref));

class DebtsController {
  final Ref ref;
  DebtsController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> add({required String name, required double amount, required String createdBy, String? note}) async {
    final now = DateTime.now();
    await _db.into(_db.debts).insert(
          DebtsCompanion.insert(
            name: name,
            amount: amount,
            date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
            note: Value(note),
            createdAt: now.toIso8601String(),
            createdBy: Value(createdBy),
          ),
        );
    ref.read(syncServiceProvider).schedulePushStatic();
    AuditLogService.logDebt(action: AuditAction.debtAdded, personName: name, amount: amount);
  }

  /// سداد كامل.
  Future<void> markPaid(int rowId, {required String paidBy}) async {
    final debt = await (_db.select(_db.debts)..where((t) => t.rowId.equals(rowId))).getSingleOrNull();
    await (_db.update(_db.debts)..where((t) => t.rowId.equals(rowId))).write(const DebtsCompanion(paid: Value(true)));
    ref.read(syncServiceProvider).schedulePushStatic();
    if (debt != null) AuditLogService.logDebt(action: AuditAction.debtPaid, personName: debt.name, amount: debt.amount);
  }

  /// سداد جزئي — بيتسجل في payment_history، والمبلغ المتبقي بيتقل.
  Future<void> addPartialPayment(int rowId, double amount, {required String paidBy}) async {
    final debt = await (_db.select(_db.debts)..where((t) => t.rowId.equals(rowId))).getSingle();
    final history = List<Map<String, dynamic>>.from(jsonDecode(debt.paymentHistoryJson) as List);
    history.add({'amount': amount, 'by': paidBy, 'at': DateTime.now().toIso8601String()});

    final newAmount = (debt.amount - amount).clamp(0, double.infinity);
    await (_db.update(_db.debts)..where((t) => t.rowId.equals(rowId))).write(
      DebtsCompanion(
        amount: Value(newAmount.toDouble()),
        paymentHistoryJson: Value(jsonEncode(history)),
        paid: Value(newAmount <= 0),
      ),
    );
    ref.read(syncServiceProvider).schedulePushStatic();
    AuditLogService.logDebt(action: AuditAction.debtPartialPaid, personName: debt.name, amount: amount);
  }

  Future<void> delete(int rowId) async {
    final debt = await (_db.select(_db.debts)..where((t) => t.rowId.equals(rowId))).getSingleOrNull();
    await (_db.delete(_db.debts)..where((t) => t.rowId.equals(rowId))).go();
    ref.read(syncServiceProvider).schedulePushStatic();
    if (debt != null) AuditLogService.logDebt(action: AuditAction.debtDeleted, personName: debt.name, amount: debt.amount);
  }
}
