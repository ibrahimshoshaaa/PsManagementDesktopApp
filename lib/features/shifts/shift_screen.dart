import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import '../shared/operation_dialog.dart';
import 'shift_history_screen.dart';
import 'shifts_controller.dart';

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});

  @override
  ConsumerState<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends ConsumerState<ShiftScreen> {
  bool _history = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final cashier = session.cashierName;
    final open = ref.watch(openShiftsStreamProvider).valueOrNull ?? <OpenShiftRow>[];
    if (cashier == null) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        Text('الشيفتات المفتوحة', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (open.isEmpty) const Card(child: ListTile(title: Text('مفيش شيفتات مفتوحة حاليًا'))),
        for (final row in open) Card(child: ListTile(
          leading: const Icon(Icons.badge_outlined, color: AppColors.accent),
          title: Text(row.cashierName), subtitle: Text('بدأ ${_dateLabel(row.startTime)}'),
        )),
      ]);
    }

    final current = open.where((row) => row.cashierName == cashier).firstOrNull;
    final start = DateTime.tryParse(current?.startTime ?? '');
    final receipts = (ref.watch(historyStreamProvider).valueOrNull ?? <HistoryRecordRow>[])
        .where((row) {
          final created = DateTime.tryParse(row.createdAt);
          return start != null && created != null && !created.isBefore(start) && row.cashier == cashier;
        }).toList();
    final total = receipts.fold<double>(0, (sum, row) => sum + row.total);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
        child: Align(alignment: AlignmentDirectional.centerStart, child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.badge_outlined), label: Text('شيفتي الحالي')),
            ButtonSegment(value: true, icon: Icon(Icons.history), label: Text('الشيفتات السابقة')),
          ],
          selected: {_history},
          onSelectionChanged: (selection) => setState(() => _history = selection.single),
        )),
      ),
      Expanded(child: _history ? ShiftHistoryScreen(cashierName: cashier) : ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [Color(0xFF214340), Color(0xFF17253B)]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('أهلًا، $cashier', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(current == null ? 'مفيش شيفت مفتوح' : 'الشيفت شغّال • بدأ ${_dateLabel(current.startTime)}',
                style: const TextStyle(color: AppColors.accent)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => current == null ? _start(cashier) : _end(cashier, receipts.length, total),
                icon: Icon(current == null ? Icons.play_arrow_rounded : Icons.stop_circle_outlined),
                label: Text(current == null ? 'ابدأ شيفت' : 'إنهاء الشيفت'),
              ),
            ]),
          ),
          if (current != null) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _metric(Icons.payments_outlined, 'إيراد الشيفت', '${total.toStringAsFixed(2)} ج'),
              _metric(Icons.receipt_long, 'الفواتير', receipts.length.toString()),
            ]),
            const SizedBox(height: 18),
            Text('آخر فواتير الشيفت', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (receipts.isEmpty) const Text('مفيش فواتير في الشيفت ده لسه'),
            for (final receipt in receipts.take(10)) Card(child: ListTile(
              title: Text(receipt.name),
              subtitle: Text(_dateLabel(receipt.createdAt)),
              trailing: Text('${receipt.total.toStringAsFixed(2)} ج'),
            )),
          ],
        ],
      )),
    ]);
  }

  Widget _metric(IconData icon, String label, String value) => SizedBox(width: 230, child: Card(
    child: ListTile(leading: Icon(icon, color: AppColors.accent), title: Text(label), subtitle: Text(value)),
  ));

  Future<void> _start(String cashier) => showOperationDialog(
    context, title: 'بدء شيفت جديد', action: 'تأكيد بدء الشيفت',
    fields: [
      Text('الكاشير: $cashier'),
      const Text('حساب الشيفت هيبدأ من وقت التأكيد، وتقدر تتابع فواتيره من هنا.'),
    ],
    save: () async {
      final result = await ref.read(shiftsControllerProvider).startShift(cashier);
      if (!result.success) throw StateError(result.lockedByOtherDeviceMessage ?? 'تعذر بدء الشيفت.');
    },
  );

  Future<void> _end(String cashier, int count, double total) async {
    Map<String, dynamic>? summary;
    await showOperationDialog(
      context, title: 'إنهاء الشيفت؟', action: 'حفظ وإغلاق الشيفت',
      fields: [Text('$count فاتورة • ${total.toStringAsFixed(2)} ج'), const Text('الملخص هيتحفظ في الشيفتات السابقة.')],
      save: () async { summary = await ref.read(shiftsControllerProvider).endShift(cashier); },
    );
    if (!mounted || summary == null || summary!.isEmpty) return;
    setState(() => _history = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الشيفت اتقفل واتحفظ في السجل.')));
  }
}

String _dateLabel(String raw) {
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return raw;
  return '${date.day}/${date.month}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
