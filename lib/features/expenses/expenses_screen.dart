import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm;

import '../../core/theme/app_colors.dart';
import '../../providers/core_providers.dart';
import '../../services/export/excel_export_service.dart';
import '../../services/export/export_paths.dart';
import 'expenses_controller.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final categoriesAsync = ref.watch(_expenseCategoriesProvider);

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('حصل خطأ: $e', style: const TextStyle(color: Colors.white))),
      data: (expenses) {
        final now = DateTime.now();
        final thisMonth = expenses.where((e) {
          final parts = e.date.split('/');
          if (parts.length != 3) return false;
          final m = int.tryParse(parts[1]);
          final y = int.tryParse(parts[2]);
          return m == now.month && y == now.year;
        }).toList();
        final totalMonth = thisMonth.fold<double>(0, (s, e) => s + e.amount);

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('المصروفات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                  Text('إجمالي الشهر: ${totalMonth.toStringAsFixed(1)} ج',
                      style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final path = await ExcelExportService.exportExpenses(expenses);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('اتحفظ في: $path'), action: SnackBarAction(label: 'افتح المجلد', onPressed: openReportsFolderInExplorer)),
                        );
                      }
                    },
                    icon: const Icon(Icons.table_chart, size: 18),
                    label: const Text('Excel'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () => _showAddDialog(context, ref, categoriesAsync.valueOrNull ?? []),
                    icon: const Icon(Icons.add),
                    label: const Text('مصروف جديد'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: expenses.isEmpty
                    ? const Center(child: Text('مفيش مصروفات مسجلة', style: TextStyle(color: Colors.white38)))
                    : ListView.separated(
                        itemCount: expenses.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final e = expenses[i];
                          return ListTile(
                            leading: const Icon(Icons.payments, color: AppColors.orange),
                            title: Text(e.title, style: const TextStyle(color: Colors.white)),
                            subtitle: Text('${e.category} · ${e.date}${e.addedBy.isNotEmpty ? " · ${e.addedBy}" : ""}',
                                style: TextStyle(color: Colors.white.withOpacity(0.4))),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${e.amount.toStringAsFixed(1)} ج',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
                                  onPressed: () => ref.read(expensesControllerProvider).delete(e.id),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, List<String> categories) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String? selectedCategory = categories.isNotEmpty ? categories.first : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('مصروف جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'البيان')),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'الفئة'),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => selectedCategory = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (titleController.text.trim().isEmpty || amount == null || selectedCategory == null) return;
                final session = ref.read(sessionProvider);
                ref.read(expensesControllerProvider).add(
                      title: titleController.text.trim(),
                      amount: amount,
                      category: selectedCategory!,
                      addedBy: session.cashierName ?? 'admin',
                      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                    );
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

final _expenseCategoriesProvider = StreamProvider<List<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.expenseCategories)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch()
      .map((rows) => rows.map((r) => r.name).toList());
});
