import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import 'drink_tables_controller.dart';

class DrinkTablesScreen extends ConsumerWidget {
  const DrinkTablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(drinkTablesStreamProvider);

    return tablesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('حصل خطأ: $e', style: const TextStyle(color: Colors.white))),
      data: (tables) {
        if (tables.isEmpty) {
          return const Center(
            child: Text('مفيش تربيزات مشروبات مضافة — أضيفها من الإعدادات', style: TextStyle(color: Colors.white38)),
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
            itemBuilder: (context, i) => _DrinkTableCard(table: tables[i]),
          ),
        );
      },
    );
  }
}

class _DrinkTableCard extends ConsumerWidget {
  final DrinkTableRow table;
  const _DrinkTableCard({required this.table});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = Map<String, int>.from(jsonDecode(table.ordersJson) as Map);
    final hasOrders = orders.isNotEmpty;
    final menu = ref.watch(menuItemsStreamProvider).valueOrNull ?? [];
    final menuPrices = {for (final m in menu) m.itemName: m.price};
    final total = orders.entries.fold<double>(0, (sum, e) => sum + e.value * (menuPrices[e.key] ?? 0));

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showSheet(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_cafe, size: 20, color: Colors.white70),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(table.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: hasOrders ? AppColors.green : Colors.white24, shape: BoxShape.circle),
                  ),
                ],
              ),
              const Spacer(),
              Text('${orders.length} أصناف', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
              const SizedBox(height: 4),
              Text('${total.toStringAsFixed(1)} ج', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              if (hasOrders)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(onPressed: () => _checkout(context, ref), child: const Text('حساب')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkout(BuildContext context, WidgetRef ref) async {
    final total = await ref.read(drinkTablesControllerProvider).checkout(table.tableId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الإجمالي: ${total.toStringAsFixed(1)} ج')));
    }
  }

  void _showSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _DrinkTableSheet(table: table),
    );
  }
}

class _DrinkTableSheet extends ConsumerWidget {
  final DrinkTableRow table;
  const _DrinkTableSheet({required this.table});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuItemsStreamProvider).valueOrNull ?? [];
    final controller = ref.read(drinkTablesControllerProvider);
    final orders = Map<String, int>.from(jsonDecode(table.ordersJson) as Map);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(table.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          if (orders.isNotEmpty) ...[
            const Text('الأوردرات الحالية', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            ...orders.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text('${e.key} × ${e.value}', style: const TextStyle(color: Colors.white))),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.red),
                        onPressed: () => controller.addOrder(table.tableId, e.key, -1),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
          ],
          const Text('أضف من المنيو', style: TextStyle(color: Colors.white70)),
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
        ],
      ),
    );
  }
}
