import '../shared/screen_ui.dart';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/core_providers.dart';
import 'recharge_controller.dart';
import '../../data/local/database.dart';
import 'package:flutter/services.dart';
import '../shared/operation_dialog.dart';

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
          ScreenIntro(
            icon: Icons.battery_charging_full, title: 'الشحن',
            description: 'تابع رصيد الشحن وسجّل العمليات من هنا.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => _showTopUpDialog(context, controller, cashier),
                icon: const Icon(Icons.add_card),
                label: const Text('شحن رصيد'),
              ),
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

  Future<void> _showAddCardDialog(BuildContext context, RechargeController controller) {
    var name = '', value = '';
    return showOperationDialog(context, title: 'إضافة كارت شحن', action: 'حفظ الكارت', fields: [
      _name('اسم الكارت', (text) => name = text),
      _amount('قيمة الكارت', (text) => value = text),
    ], save: () => controller.addCard(name, int.parse(value)));
  }

  Future<void> _showTopUpDialog(BuildContext context, RechargeController controller, String cashier) {
    var amount = '', note = '';
    return showOperationDialog(context, title: 'إضافة رصيد شحن', action: 'حفظ العملية', fields: [
      _amount('قيمة الشحن', (text) => amount = text),
      TextFormField(decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
        onChanged: (text) => note = text.trim()),
    ], save: () => controller.addBalance(double.parse(amount), note, cashier: cashier));
  }

  Future<void> _showRedeemDialog(BuildContext context, RechargeController controller, String cashier, List<RechargeCardRow> cards) {
    return showDialog<void>(context: context, builder: (_) => _RedeemDialog(
      cards: cards, submit: ({required type, required name, required value}) =>
        controller.redeem(type: type, name: name, value: value, cashier: cashier),
    ));
  }
}

Widget _name(String label, ValueChanged<String> changed) => TextFormField(
  autofocus: true, textInputAction: TextInputAction.next,
  decoration: InputDecoration(labelText: label),
  validator: (value) => value == null || value.trim().isEmpty ? 'اكتب الاسم' : null,
  onChanged: (value) => changed(value.trim()),
);

Widget _amount(String label, ValueChanged<String> changed) => TextFormField(
  keyboardType: TextInputType.number,
  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  decoration: InputDecoration(labelText: label, suffixText: 'ج', prefixIcon: const Icon(Icons.payments_outlined)),
  validator: (value) {
    final amount = int.tryParse(value ?? '');
    return amount == null || amount <= 0 ? 'اكتب قيمة أكبر من صفر' : null;
  },
  onChanged: changed,
);

class _RedeemDialog extends StatefulWidget {
  const _RedeemDialog({required this.cards, required this.submit});
  final List<RechargeCardRow> cards;
  final Future<void> Function({required String type, required String name, required double value}) submit;

  @override
  State<_RedeemDialog> createState() => _RedeemDialogState();
}

class _RedeemDialogState extends State<_RedeemDialog> {
  final _form = GlobalKey<FormState>();
  late bool _free = widget.cards.isEmpty;
  RechargeCardRow? _card;
  String _clientName = '', _value = '';
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final card = _card;
    if (!_free && card == null) {
      setState(() => _error = 'اختار الكارت الأول.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.submit(type: _free ? 'free' : 'card', name: _clientName,
        value: _free ? double.parse(_value) : card!.value.toDouble());
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() {
        _busy = false;
        _error = error is StateError ? error.message.toString() : 'تعذر حفظ العملية.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('استخدام رصيد الشحن'),
    content: SizedBox(width: 460, child: SingleChildScrollView(child: Form(
      key: _form,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.cards.isNotEmpty) ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('كارت محفوظ'), icon: Icon(Icons.credit_card)),
              ButtonSegment(value: true, label: Text('شحن حر'), icon: Icon(Icons.edit_outlined)),
            ],
            selected: {_free},
            onSelectionChanged: _busy ? null : (values) => setState(() { _free = values.single; _error = null; }),
          ),
          const SizedBox(height: 14),
        ],
        _name('اسم العميل', (value) => _clientName = value),
        const SizedBox(height: 12),
        if (_free)
          _amount('القيمة بالجنيه', (value) => _value = value)
        else
          DropdownButtonFormField<RechargeCardRow>(
            decoration: const InputDecoration(labelText: 'اختار كارت'),
            isExpanded: true,
            items: [for (final row in widget.cards)
              DropdownMenuItem(value: row, child: Text('${row.name} • ${row.value} ج'))],
            onChanged: (value) => setState(() => _card = value),
          ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: AppColors.red))),
      ]),
    ))),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('رجوع')),
      FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.check), label: const Text('تسجيل الشحن')),
    ],
  );
}
