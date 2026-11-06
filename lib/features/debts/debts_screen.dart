import '../shared/screen_ui.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import '../../services/export/excel_export_service.dart';
import '../../services/export/export_paths.dart';
import 'debts_controller.dart';
import '../shared/operation_dialog.dart';

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
          ScreenIntro(
            icon: Icons.account_balance_wallet_outlined, title: 'المديونيات',
            description: 'إجمالي المستحق: ${totalUnpaid.toStringAsFixed(2)} ج',
            actions: [
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
                    ? const ScreenEmpty(icon: Icons.account_balance_wallet_outlined, title: 'مفيش مديونيات مسجلة', hint: 'اضغط مديونية جديدة عشان تتابع المستحق والدفعات.')
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

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) {
    var name = '', amount = '', note = '';
    return showOperationDialog(
      context,
      title: 'تسجيل مديونية جديدة',
      action: 'حفظ المديونية',
      fields: [
        TextFormField(autofocus: true, decoration: const InputDecoration(labelText: 'اسم العميل', prefixIcon: Icon(Icons.person_outline)),
          onChanged: (value) => name = value.trim(),
          validator: (value) => value == null || value.trim().isEmpty ? 'اكتب اسم العميل' : null),
        _amountField('المبلغ المستحق بالجنيه', (value) => amount = value),
        TextFormField(maxLines: 2, decoration: const InputDecoration(labelText: 'سبب المديونية (اختياري)'),
          onChanged: (value) => note = value.trim()),
      ],
      save: () => ref.read(debtsControllerProvider).add(
        name: name, amount: parseMoney(amount)!, note: note.isEmpty ? null : note,
        createdBy: ref.read(sessionProvider).cashierName ?? 'أدمن',
      ),
    );
  }
}

Widget _amountField(String label, ValueChanged<String> onChanged) => TextFormField(
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.payments_outlined)),
  validator: (value) => parseMoney(value ?? '') == null ? 'اكتب مبلغًا أكبر من صفر' : null,
  onChanged: onChanged,
);

class _DebtTile extends ConsumerWidget {
  const _DebtTile({required this.debt});
  final DebtRow debt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final controller = ref.read(debtsControllerProvider);
    final paidBy = session.cashierName ?? 'أدمن';
    return Card(child: ListTile(
      leading: Icon(debt.paid ? Icons.check_circle_outline : Icons.person_outline,
        color: debt.paid ? AppColors.green : AppColors.orange),
      title: Text(debt.name),
      subtitle: Text('${debt.paid ? 'تم السداد' : 'متبقي ${debt.amount.toStringAsFixed(2)} ج'} • ${debt.date}'
          '${debt.note == null || debt.note!.isEmpty ? '' : '\n${debt.note}'}'),
      onTap: () => _payments(context),
      trailing: PopupMenuButton<String>(
        tooltip: 'إجراءات المديونية',
        onSelected: (action) {
          if (action == 'history') {
            _payments(context);
          } else if (action == 'partial' || action == 'add') {
            _amount(context, controller, paidBy, adding: action == 'add');
          } else if (action == 'pay') {
            showOperationDialog(context, title: 'سداد كامل لـ ${debt.name}؟', action: 'تأكيد السداد',
              fields: [Text('المستحق: ${debt.amount.toStringAsFixed(2)} ج')],
              save: () => controller.markPaid(debt.rowId, paidBy: paidBy));
          } else if (action == 'delete') {
            showOperationDialog(context, title: 'حذف مديونية ${debt.name}؟', action: 'حذف',
              fields: const [Text('هيتم حذف المديونية وسجل دفعاتها.')],
              save: () => controller.delete(debt.rowId));
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'history', child: Text('سجل الدفعات')),
          const PopupMenuItem(value: 'add', child: Text('إضافة مبلغ للمديونية')),
          if (!debt.paid) ...[
            const PopupMenuItem(value: 'partial', child: Text('سداد جزء')),
            const PopupMenuItem(value: 'pay', child: Text('سداد كامل')),
          ],
          if (session.role == UserRole.admin) const PopupMenuItem(value: 'delete', child: Text('حذف')),
        ],
      ),
    ));
  }

  Future<void> _amount(BuildContext context, DebtsController controller, String paidBy, {required bool adding}) {
    var amount = '';
    return showOperationDialog(
      context, title: adding ? 'إضافة مبلغ لـ ${debt.name}' : 'سداد جزئي لـ ${debt.name}',
      action: adding ? 'إضافة' : 'حفظ الدفعة',
      fields: [
        Text('المتبقي حاليًا: ${(debt.paid ? 0 : debt.amount).toStringAsFixed(2)} ج'),
        _amountField(adding ? 'المبلغ الإضافي' : 'المبلغ المدفوع', (value) => amount = value),
      ],
      save: () => adding
          ? controller.addAmount(debt.rowId, parseMoney(amount)!)
          : controller.addPartialPayment(debt.rowId, parseMoney(amount)!, paidBy: paidBy),
    );
  }

  Future<void> _payments(BuildContext context) {
    final payments = (jsonDecode(debt.paymentHistoryJson) as List).whereType<Map>().toList().reversed;
    return showDialog<void>(context: context, builder: (dialog) => AlertDialog(
      title: Text('دفعات ${debt.name}'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          if (payments.isEmpty) const Text('مفيش دفعات متسجلة'),
          for (final payment in payments) ListTile(
            title: Text('${payment['amount']} ج'),
            subtitle: Text('${payment['by'] ?? ''} • ${payment['at'] ?? ''}'),
          ),
        ],
      ))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('رجوع'))],
    ));
  }
}
