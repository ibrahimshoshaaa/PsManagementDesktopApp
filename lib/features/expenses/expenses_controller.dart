import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uuid/uuid.dart';

import '../../data/local/database.dart';
import '../../data/local/audit_log_service.dart';
import '../../providers/core_providers.dart';

final expensesControllerProvider = Provider<ExpensesController>((ref) => ExpensesController(ref));

class ExpensesController {
  final Ref ref;
  ExpensesController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> add({
    required String title,
    required double amount,
    required String category,
    required String addedBy,
    String? note,
    DateTime? date,
  }) async {
    if (title.trim().isEmpty || !amount.isFinite || amount <= 0) throw StateError('اكتب بيانات مصروف صحيحة.');
    final now = DateTime.now();
    final expenseDate = date ?? now;
    await _db.into(_db.expenses).insert(
          ExpensesCompanion.insert(
            id: const Uuid().v4(),
            title: title,
            amount: amount,
            category: category,
            date: '${expenseDate.day}/${expenseDate.month}/${expenseDate.year}',
            note: Value(note),
            addedBy: Value(addedBy),
            createdAt: now.toIso8601String(),
          ),
        );
    AuditLogService.log(action: AuditAction.expenseAdded, actionDetails: 'إضافة مصروف $title');
  }

  Future<void> edit(ExpenseRow original, {
    required String title, required double amount, required String category, required DateTime date, String? note,
  }) async {
    if (title.trim().isEmpty || !amount.isFinite || amount <= 0) throw StateError('اكتب بيانات مصروف صحيحة.');
    await (_db.update(_db.expenses)..where((row) => row.id.equals(original.id))).write(
      ExpensesCompanion(
        title: Value(title), amount: Value(amount), category: Value(category),
        date: Value('${date.day}/${date.month}/${date.year}'), note: Value(note),
      ),
    );
    AuditLogService.log(action: AuditAction.expenseUpdated, actionDetails: 'تعديل مصروف $title');
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.expenses)..where((t) => t.id.equals(id))).go();
  }

  Future<void> addCategory(String name) async {
    final existing = await _db.select(_db.expenseCategories).get();
    await _db.into(_db.expenseCategories).insert(
          ExpenseCategoriesCompanion.insert(name: name, sortOrder: Value(existing.length)),
        );
  }
}
