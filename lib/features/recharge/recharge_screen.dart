import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/core_providers.dart';
import 'recharge_controller.dart';

class RechargeScreen extends ConsumerWidget {
  const RechargeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).valueOrNull;
    final cards = ref.watch(rechargeCardsStreamProvider).valueOrNull ?? [];
    final transactions = ref.watch(rechargeTransactionsStreamProvider).valueOrNull ?? [];
    final controller = ref.read(rechargeControllerProvider);
    final session = ref.watch(sessionProvider);
    final cashier = session.cashierName ?? 'أدمن';

    if (config == null) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('الشحن', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _showTopUpDialog(context, controller, cashier),
                icon: const Icon(Icons.add_card),
                label: const Text('شحن رصيد'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showRedeemDialog(context, controller, cashier, cards),
                icon: const Icon(Icons.qr_code),
                label: const Text('استخدام كارت/شحن حر'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppColors.accent, size: 32),
                  const SizedBox(width: 16),
                  Text('${config.rechargeBalance} ج', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 8),
                  const Text('الرصيد المتاح', style: TextStyle(color: Colors.white38)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('الكروت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
                            onPressed: () => _showAddCardDialog(context, controller),
                          ),
                        ],
                      ),
                      Expanded(
                        child: ListView(
                          children: cards
                              .map((c) => ListTile(
                                    leading: const Icon(Icons.credit_card, color: Colors.white54),
                                    title: Text(c.name, style: const TextStyle(color: Colors.white)),
                                    trailing: Text('${c.value} ج', style: const TextStyle(color: Colors.white70)),
                                    onLongPress: () => controller.removeCard(c.rowId),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('آخر المعاملات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: transactions.map((t) {
                            final data = Map<String, dynamic>.from(jsonDecode(t.dataJson) as Map);
                            final isTopUp = data['type'] == 'top_up';
                            return ListTile(
                              leading: Icon(isTopUp ? Icons.add_circle : Icons.remove_circle, color: isTopUp ? AppColors.green : AppColors.red),
                              title: Text(data['name']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                              subtitle: Text('${data['cashier'] ?? ''} · ${data['date'] ?? ''}', style: const TextStyle(color: Colors.white38)),
                              trailing: Text('${(data['value'] as num?)?.toStringAsFixed(1) ?? 0} ج', style: const TextStyle(color: Colors.white)),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCardDialog(BuildContext context, RechargeController controller) {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('كارت جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم الكارت')),
            const SizedBox(height: 12),
            TextField(controller: valueController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'القيمة')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(valueController.text);
              if (nameController.text.trim().isEmpty || value == null) return;
              controller.addCard(nameController.text.trim(), value);
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showTopUpDialog(BuildContext context, RechargeController controller, String cashier) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('شحن رصيد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
            const SizedBox(height: 12),
            TextField(controller: noteController, decoration: const InputDecoration(labelText: 'ملاحظة')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount == null) return;
              controller.addBalance(amount, noteController.text.trim(), cashier: cashier);
              Navigator.pop(context);
            },
            child: const Text('شحن'),
          ),
        ],
      ),
    );
  }

  void _showRedeemDialog(BuildContext context, RechargeController controller, String cashier, List cards) {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    String type = 'card';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('استخدام كارت / شحن حر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'card', label: Text('كارت')),
                  ButtonSegment(value: 'free', label: Text('شحن حر')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setState(() => type = s.first),
              ),
              const SizedBox(height: 12),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم العميل/الكارت')),
              const SizedBox(height: 12),
              TextField(controller: valueController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'القيمة')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(valueController.text);
                if (nameController.text.trim().isEmpty || value == null) return;
                controller.redeem(type: type, name: nameController.text.trim(), value: value, cashier: cashier);
                Navigator.pop(context);
              },
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }
}
