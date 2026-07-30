import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/core_providers.dart';
import 'shifts_controller.dart';

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});
  @override
  ConsumerState<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends ConsumerState<ShiftScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(shiftsControllerProvider).refreshShiftsHistoryFromRemote());
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final openShifts = ref.watch(openShiftsStreamProvider).valueOrNull ?? [];
    final myShift =
        session.cashierName != null ? openShifts.where((s) => s.cashierName == session.cashierName).firstOrNull : null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الشيفت', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 20),
          if (session.role == UserRole.cashier) _MyShiftCard(cashierName: session.cashierName!, myShift: myShift),
          if (session.role == UserRole.admin) ...[
            const Text('الشيفتات المفتوحة الآن', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (openShifts.isEmpty)
              const Text('مفيش شيفتات مفتوحة دلوقتي', style: TextStyle(color: Colors.white38))
            else
              ...openShifts.map((s) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.person, color: AppColors.green),
                      title: Text(s.cashierName, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('بدأ الساعة ${DateTime.tryParse(s.startTime)?.toString().substring(11, 16) ?? s.startTime}',
                          style: const TextStyle(color: Colors.white38)),
                    ),
                  )),
          ],
        ],
      ),
    );
  }
}

class _MyShiftCard extends ConsumerWidget {
  final String cashierName;
  final dynamic myShift;
  const _MyShiftCard({required this.cashierName, required this.myShift});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(shiftsControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: myShift == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مفيش شيفت مفتوح', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await controller.startShift(cashierName);
                      if (context.mounted && !result.success) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(result.lockedByOtherDeviceMessage ?? 'حصل خطأ')));
                      }
                    },
                    icon: const Icon(Icons.play_circle),
                    label: const Text('بدء الشيفت'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 10, color: AppColors.green),
                      const SizedBox(width: 8),
                      Text(
                        'شيفت شغال — بدأ الساعة ${DateTime.tryParse(myShift.startTime as String)?.toString().substring(11, 16) ?? ''}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.redDark),
                    onPressed: () async {
                      final summary = await controller.endShift(cashierName);
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('ملخص الشيفت'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('إجمالي الإيراد: ${(summary['total_revenue'] as double?)?.toStringAsFixed(1) ?? 0} ج'),
                                Text('عدد الجلسات: ${summary['sessions_count'] ?? 0}'),
                              ],
                            ),
                            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تمام'))],
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.stop_circle),
                    label: const Text('إنهاء الشيفت'),
                  ),
                ],
              ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
