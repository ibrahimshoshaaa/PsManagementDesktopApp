import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/table_logic.dart';
import '../../providers/core_providers.dart';
import '../shared/qr_code_dialog.dart';
import 'tables_controller.dart';

class TablesScreen extends ConsumerWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(tickerProvider);
    final tablesAsync = ref.watch(gameTablesStreamProvider);

    return tablesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('حصل خطأ: $e', style: const TextStyle(color: Colors.white))),
      data: (tables) {
        if (tables.isEmpty) {
          return const Center(
            child: Text('مفيش تربيزات مضافة — أضيفها من الإعدادات', style: TextStyle(color: Colors.white38)),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(20),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.05,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: tables.length,
            itemBuilder: (context, i) => _TableCard(table: tables[i]),
          ),
        );
      },
    );
  }
}

class _TableCard extends ConsumerWidget {
  final GameTableRow table;
  const _TableCard({required this.table});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(tablesControllerProvider);
    final isActive = table.isActive;
    final cost = isActive ? table.hourlyTimeCost : 0.0;
    final isBilliard = table.tableType == 'billiard';
    final glowColor = table.isPaused ? AppColors.amber : AppColors.accent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? glowColor : Colors.white12, width: isActive ? 1.5 : 1),
        boxShadow:
            isActive ? [BoxShadow(color: glowColor.withOpacity(0.25), blurRadius: 14, spreadRadius: 1)] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTableSheet(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(table.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isBilliard ? Colors.purple : AppColors.green).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: (isBilliard ? Colors.purple : AppColors.green).withOpacity(0.8)),
                      ),
                      child: Text(isBilliard ? '🎱 بلياردو' : '🏓 بينج',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isBilliard ? Colors.purple : AppColors.green)),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _showQr(context, ref),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.qr_code_2, size: 18, color: Colors.white38),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Text(
                    isActive ? table.timerText() : '—',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: table.isPaused ? AppColors.amber : Colors.white,
                      shadows: isActive ? [Shadow(color: glowColor.withOpacity(0.5), blurRadius: 8)] : [],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    isActive ? '${cost.toStringAsFixed(1)} ج' : 'متاحة',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
                ),
                const Spacer(),
                if (!isActive)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(onPressed: () => controller.start(table.tableId), child: const Text('تشغيل')),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: IconButton.filledTonal(
                          onPressed: () =>
                              table.isPaused ? controller.resume(table.tableId) : controller.pause(table.tableId),
                          icon: Icon(table.isPaused ? Icons.play_arrow : Icons.pause),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: IconButton.filledTonal(
                          style: IconButton.styleFrom(backgroundColor: AppColors.orange.withOpacity(0.2)),
                          onPressed: () => _showTableSheet(context, ref),
                          icon: const Icon(Icons.fastfood, color: AppColors.orange),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: IconButton.filledTonal(
                          style: IconButton.styleFrom(backgroundColor: AppColors.redDark.withOpacity(0.3)),
                          onPressed: () => _confirmStop(context, ref),
                          icon: const Icon(Icons.stop, color: AppColors.red),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQr(BuildContext context, WidgetRef ref) {
    final shopId = ref.read(appConfigProvider).valueOrNull?.shopId;
    if (shopId == null) return;
    final isBilliard = table.tableType == 'billiard';
    showQrCodeDialog(
      context,
      name: table.name,
      url: QrLinkBuilder.table(shopId, table.tableId),
      color: isBilliard ? Colors.purple : AppColors.green,
      typeLabel: isBilliard ? '🎱 بلياردو' : '🏓 بينج',
      icon: Icons.table_bar,
      subtitle: 'سيتمكن العميل من متابعة الوقت والحساب\nوإرسال طلبات المشروبات للتربيزة',
    );
  }

  void _confirmStop(BuildContext context, WidgetRef ref) async {
    final byGame = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء الجلسة'),
        content: Text('طريقة الحساب لـ ${table.name}؟\nبالساعة: ${table.hourlyTimeCost.toStringAsFixed(1)} ج · باللعبة: ${table.gamePrice} ج'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('بالساعة')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('باللعبة')),
        ],
      ),
    );
    if (byGame == null) return;
    final result = await ref.read(tablesControllerProvider).stop(table.tableId, byGame: byGame);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الإجمالي: ${(result['total'] as double).toStringAsFixed(1)} ج')),
      );
    }
  }

  void _showTableSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _TableDetailSheet(table: table),
    );
  }
}

class _TableDetailSheet extends ConsumerWidget {
  final GameTableRow table;
  const _TableDetailSheet({required this.table});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuItemsStreamProvider).valueOrNull ?? [];
    final controller = ref.read(tablesControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(table.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          const Text('أضف من البوفيه', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: menu
                .map((m) => ActionChip(
                      label: Text('${m.itemName} (${m.price} ج)'),
                      onPressed: () => controller.addOrder(table.tableId, m.itemName, 1),
                    ))
                .toList(),
          ),
          if (table.isActive) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('إلغاء الجلسة من غير حساب؟'),
                      content: const Text('مش هيتسجل أي فاتورة.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إلغاء')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await controller.cancel(table.tableId);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('إلغاء الجلسة من غير حساب'),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
