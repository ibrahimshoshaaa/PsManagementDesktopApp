import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/local/audit_log_service.dart';
import '../../providers/core_providers.dart';

final debtsControllerProvider = Provider<DebtsController>((ref) => DebtsController(ref));

class DebtsController {
  final Ref ref;
  DebtsController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> add({required String name, required double amount, required String createdBy, String? note}) async {
    if (name.trim().isEmpty || !amount.isFinite || amount <= 0) throw StateError('اكتب مبلغًا موجبًا واسم العميل.');
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
    AuditLogService.logDebt(action: AuditAction.debtAdded, personName: name, amount: amount);
  }

  Future<void> markPaid(int rowId, {required String paidBy}) => _payment(rowId, null, paidBy);

  Future<void> addPartialPayment(int rowId, double amount, {required String paidBy}) =>
      _payment(rowId, amount, paidBy);

  Future<void> _payment(int rowId, double? requested, String paidBy) => _db.transaction(() async {
    final debt = await (_db.select(_db.debts)..where((row) => row.rowId.equals(rowId))).getSingleOrNull();
    if (debt == null || debt.paid) throw StateError('المديونية دي اتسدّدت بالفعل.');
    final amount = requested ?? debt.amount;
    if (!amount.isFinite || amount <= 0 || amount > debt.amount) {
      throw StateError('مبلغ السداد لازم يكون أكبر من صفر ومايزيدش عن المستحق.');
    }
    final history = List<Map<String, dynamic>>.from(jsonDecode(debt.paymentHistoryJson) as List);
    history.add({'amount': amount, 'by': paidBy, 'at': DateTime.now().toIso8601String()});
    final remaining = double.parse((debt.amount - amount).toStringAsFixed(2));
    await (_db.update(_db.debts)..where((row) => row.rowId.equals(rowId))).write(
      DebtsCompanion(amount: Value(remaining), paymentHistoryJson: Value(jsonEncode(history)),
        paid: Value(remaining == 0)),
    );
    AuditLogService.logDebt(
      action: remaining == 0 ? AuditAction.debtPaid : AuditAction.debtPartialPaid,
      personName: debt.name, amount: amount,
    );
  });

  Future<void> addAmount(int rowId, double amount) => _db.transaction(() async {
    if (!amount.isFinite || amount <= 0) throw StateError('اكتب مبلغًا أكبر من صفر.');
    final debt = await (_db.select(_db.debts)..where((row) => row.rowId.equals(rowId))).getSingle();
    await (_db.update(_db.debts)..where((row) => row.rowId.equals(rowId))).write(
      DebtsCompanion(amount: Value((debt.paid ? 0 : debt.amount) + amount), paid: const Value(false)),
    );
    AuditLogService.logDebt(action: AuditAction.debtAmountAdded, personName: debt.name, amount: amount);
  });

  Future<void> delete(int rowId) async {
    final debt = await (_db.select(_db.debts)..where((t) => t.rowId.equals(rowId))).getSingleOrNull();
    await (_db.delete(_db.debts)..where((t) => t.rowId.equals(rowId))).go();
    if (debt != null) AuditLogService.logDebt(action: AuditAction.debtDeleted, personName: debt.name, amount: debt.amount);
  }
}
