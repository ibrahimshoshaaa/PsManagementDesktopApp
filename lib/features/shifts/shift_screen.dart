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
              ...openShifts.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.green.withOpacity(0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.person, color: AppColors.green, size: 20),
                      ),
                      title: Text(s.cashierName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: myShift != null ? AppColors.green.withOpacity(0.6) : Colors.white12, width: 1.5),
        boxShadow: myShift != null
            ? [BoxShadow(color: AppColors.green.withOpacity(0.2), blurRadius: 16, spreadRadius: 1)]
            : [],
      ),
      padding: const EdgeInsets.all(20),
      child: myShift == null
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle),
                  child: const Icon(Icons.badge_outlined, color: Colors.white38, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('مفيش شيفت مفتوح دلوقتي', style: TextStyle(color: Colors.white70, fontSize: 15)),
                ),
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.green.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.badge, color: AppColors.green, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('شيفت شغال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(
                            'بدأ الساعة ${DateTime.tryParse(myShift.startTime as String)?.toString().substring(11, 16) ?? ''}',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
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
                ),
              ],
            ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
