import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import '../../services/export/excel_export_service.dart';
import '../../services/export/export_paths.dart';
import 'debts_controller.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsStreamProvider);

    return debtsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('حصل خطأ: $e', style: const TextStyle(color: Colors.white))),
      data: (debts) {
        final unpaid = debts.where((d) => !d.paid).toList();
        final totalUnpaid = unpaid.fold<double>(0, (s, d) => s + d.amount);

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('المديونيات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                  Text('إجمالي المستحق: ${totalUnpaid.toStringAsFixed(1)} ج',
                      style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final path = await ExcelExportService.exportDebts(debts);
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
                    onPressed: () => _showAddDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('مديونية جديدة'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: debts.isEmpty
                    ? const Center(child: Text('مفيش مديونيات مسجلة', style: TextStyle(color: Colors.white38)))
                    : ListView.separated(
                        itemCount: debts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) => _DebtTile(debt: debts[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مديونية جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ'),
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
              if (nameController.text.trim().isEmpty || amount == null) return;
              final session = ref.read(sessionProvider);
              ref.read(debtsControllerProvider).add(
                    name: nameController.text.trim(),
                    amount: amount,
                    createdBy: session.cashierName ?? 'admin',
                    note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                  );
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _DebtTile extends ConsumerWidget {
  final DebtRow debt;
  const _DebtTile({required this.debt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(sessionProvider);
    return ListTile(
      leading: Icon(Icons.person, color: debt.paid ? Colors.white24 : AppColors.red),
      title: Text(
        debt.name,
        style: TextStyle(
          color: debt.paid ? Colors.white38 : Colors.white,
          decoration: debt.paid ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text('${debt.date}${debt.note != null && debt.note!.isNotEmpty ? " · ${debt.note}" : ""}',
          style: TextStyle(color: Colors.white.withOpacity(0.4))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${debt.amount.toStringAsFixed(1)} ج',
              style: TextStyle(color: debt.paid ? Colors.white38 : Colors.white, fontWeight: FontWeight.bold)),
          if (!debt.paid) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _showPartialDialog(context, ref, session.cashierName ?? 'admin'),
              child: const Text('سداد جزئي'),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: AppColors.green),
              onPressed: () => ref.read(debtsControllerProvider).markPaid(debt.rowId, paidBy: session.cashierName ?? 'admin'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
            onPressed: () => ref.read(debtsControllerProvider).delete(debt.rowId),
          ),
        ],
      ),
    );
  }

  void _showPartialDialog(BuildContext context, WidgetRef ref, String paidBy) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('سداد جزئي — ${debt.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ المدفوع'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0) return;
              ref.read(debtsControllerProvider).addPartialPayment(debt.rowId, amount, paidBy: paidBy);
              Navigator.pop(context);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}
