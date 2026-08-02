import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
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
  }) async {
    final now = DateTime.now();
    await _db.into(_db.expenses).insert(
          ExpensesCompanion.insert(
            id: now.millisecondsSinceEpoch.toString(),
            title: title,
            amount: amount,
            category: category,
            date: '${now.day}/${now.month}/${now.year}',
            note: Value(note),
            addedBy: Value(addedBy),
            createdAt: now.toIso8601String(),
          ),
        );
    ref.read(syncServiceProvider).schedulePushStatic();
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.expenses)..where((t) => t.id.equals(id))).go();
    ref.read(syncServiceProvider).schedulePushStatic();
  }

  Future<void> addCategory(String name) async {
    final existing = await _db.select(_db.expenseCategories).get();
    await _db.into(_db.expenseCategories).insert(
          ExpenseCategoriesCompanion.insert(name: name, sortOrder: Value(existing.length)),
        );
    ref.read(syncServiceProvider).schedulePushStatic();
  }
}
