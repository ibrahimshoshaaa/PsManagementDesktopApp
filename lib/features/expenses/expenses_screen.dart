import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm;

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../shared/operation_dialog.dart';
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
                    onPressed: () => _edit(context, ref, categoriesAsync.valueOrNull ?? []),
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
                            onTap: () => _edit(context, ref, categoriesAsync.valueOrNull ?? [], e),
                            subtitle: Text('${e.category} · ${e.date}${e.addedBy.isNotEmpty ? " · ${e.addedBy}" : ""}',
                                style: TextStyle(color: Colors.white.withOpacity(0.4))),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${e.amount.toStringAsFixed(1)} ج',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
                                  onPressed: () => showOperationDialog(context,
                                    title: 'حذف مصروف ${e.title}؟', action: 'حذف',
                                    fields: [Text('${e.amount.toStringAsFixed(2)} ج • ${e.date}')],
                                    save: () => ref.read(expensesControllerProvider).delete(e.id),
                                  ),
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

  Future<void> _edit(BuildContext context, WidgetRef ref, List<String> categories, [ExpenseRow? original]) {
    final choices = {if (original != null) original.category, ...categories, 'أخرى'}.toList();
    var title = original?.title ?? '';
    var amount = original?.amount.toString() ?? '';
    var note = original?.note ?? '';
    var category = original?.category ?? choices.first;
    var date = DateTime.now();
    if (original != null) {
      final pieces = original.date.split('/').map(int.tryParse).toList();
      if (pieces.length == 3 && pieces.every((part) => part != null)) {
        date = DateTime(pieces[2]!, pieces[1]!, pieces[0]!);
      }
    }
    return showOperationDialog(
      context,
      title: original == null ? 'تسجيل مصروف جديد' : 'تعديل المصروف',
      action: 'حفظ المصروف',
      fields: [
        TextFormField(initialValue: title, autofocus: true,
          decoration: const InputDecoration(labelText: 'بيان المصروف', prefixIcon: Icon(Icons.description_outlined)),
          onChanged: (value) => title = value.trim(),
          validator: (value) => value == null || value.trim().isEmpty ? 'اكتب بيان المصروف' : null),
        TextFormField(initialValue: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'المبلغ بالجنيه', prefixIcon: Icon(Icons.payments_outlined)),
          onChanged: (value) => amount = value,
          validator: (value) => parseMoney(value ?? '') == null ? 'اكتب مبلغًا أكبر من صفر' : null),
        DropdownButtonFormField<String>(value: category, isExpanded: true,
          decoration: const InputDecoration(labelText: 'فئة المصروف'),
          items: [for (final choice in choices) DropdownMenuItem(value: choice, child: Text(choice))],
          onChanged: (value) { if (value != null) category = value; }),
        StatefulBuilder(builder: (context, redraw) => OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text('تاريخ المصروف: ${date.day}/${date.month}/${date.year}'),
          onPressed: () async {
            final picked = await showDatePicker(context: context, initialDate: date,
              firstDate: DateTime(2000), lastDate: DateTime.now());
            if (picked != null && context.mounted) redraw(() => date = picked);
          },
        )),
        TextFormField(initialValue: note, maxLines: 2,
          decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
          onChanged: (value) => note = value.trim()),
      ],
      save: () {
        final controller = ref.read(expensesControllerProvider);
        final value = parseMoney(amount)!;
        return original == null
            ? controller.add(title: title, amount: value, category: category, date: date,
                addedBy: ref.read(sessionProvider).cashierName ?? 'أدمن', note: note.isEmpty ? null : note)
            : controller.edit(original, title: title, amount: value, category: category, date: date,
                note: note.isEmpty ? null : note);
      },
    );
  }
}

final _expenseCategoriesProvider = StreamProvider<List<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.expenseCategories)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch()
      .map((rows) => rows.map((r) => r.name).toList());
});
