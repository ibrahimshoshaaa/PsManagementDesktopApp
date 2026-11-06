import '../shared/screen_ui.dart';
import '../../core/theme/app_colors.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import '../settings/settings_controller.dart';
import '../shared/operation_dialog.dart';
import '../settings/menu_item_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _query = '';

  Future<void> _editStock(String item, int quantity) async {
    final key = GlobalKey<FormState>();
    var value = quantity;
    final result = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('تعديل رصيد $item'),
        content: Form(
          key: key,
          child: TextFormField(
            initialValue: quantity.toString(),
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الكمية المتبقية'),
            validator: (text) {
              final parsed = int.tryParse(text?.trim() ?? '');
              if (parsed == null || parsed < 0) return 'اكتب كمية صحيحة';
              value = parsed;
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(dialog, value);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    await ref.read(settingsControllerProvider).setInventoryQuantity(item, result);
  }

  Future<void> _receive(List<MenuItemRow> items) {
    final quantities = <String, String>{};
    return showOperationDialog(context,
      title: 'توريد كميات للمخزون',
      action: 'إضافة الكميات',
      fields: [
        const Text('اكتب الكمية الجديدة لكل صنف. هتتضاف فوق الرصيد الحالي.'),
        for (final item in items)
          TextFormField(
            decoration: InputDecoration(labelText: item.itemName, suffixText: 'قطعة'),
            keyboardType: TextInputType.number,
            onChanged: (value) => quantities[item.itemName] = value.trim(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final number = int.tryParse(value.trim());
              return number == null || number <= 0 ? 'اكتب كمية أكبر من صفر' : null;
            },
          ),
      ],
      save: () {
        final additions = {for (final entry in quantities.entries)
          if (entry.value.isNotEmpty) entry.key: int.parse(entry.value)};
        if (additions.isEmpty) throw StateError('اكتب كمية لصنف واحد على الأقل.');
        return ref.read(settingsControllerProvider).receiveStock(additions);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuItemsStreamProvider).valueOrNull ?? <MenuItemRow>[];
    final stock = {
      for (final row in ref.watch(inventoryStreamProvider).valueOrNull ?? <InventoryItemRow>[])
        row.itemName: row.quantity,
    };
    final sold = <String, int>{};
    final today = DateTime.now();
    for (final record in ref.watch(historyStreamProvider).valueOrNull ?? <HistoryRecordRow>[]) {
      if (!DateUtils.isSameDay(DateTime.tryParse(record.createdAt)?.toLocal(), today)) continue;
      final orders = jsonDecode(record.ordersJson);
      if (orders is! Map) continue;
      for (final item in orders.entries) {
        final quantity = item.value;
        if (item.key is String && quantity is num) {
          sold.update(item.key as String, (total) => total + quantity.toInt(), ifAbsent: quantity.toInt);
        }
      }
    }
    final items = {
      for (final row in menu) row.itemName,
      ...stock.keys,
      ...sold.keys,
    }.where((item) => item.toLowerCase().contains(_query)).toList()..sort();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ScreenIntro(
            icon: Icons.inventory_2_outlined, title: 'رصيد البوفيه',
            description: 'تابع الكميات والمبيعات، أو زوّد الرصيد بتوريد جديد.',
            actions: [
            FilledButton.icon(
              onPressed: () => showMenuItemDialog(context),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('صنف جديد مع رصيد'),
            ),
            OutlinedButton.icon(
              onPressed: menu.isEmpty ? null : () => _receive(menu),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('توريد كميات'),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'ابحث عن صنف',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (text) => setState(() => _query = text.trim().toLowerCase()),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: items.isEmpty
                ? const ScreenEmpty(icon: Icons.inventory_2_outlined, title: 'مفيش أصناف ظاهرة', hint: 'غيّر كلمة البحث أو أضف صنف وحدد كميته الافتتاحية.')
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final quantity = stock[item];
                      return Card(
                        child: ListTile(
                          leading: ScreenIcon(Icons.inventory_2_outlined, color: quantity == 0 ? AppColors.red : AppColors.accent),
                          title: Text(item),
                          subtitle: Text('المباع اليوم  ${sold[item] ?? 0}'),
                          trailing: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(quantity == null ? 'غير محدد' : 'متبقي  $quantity'),
                              IconButton(
                                tooltip: 'تعديل الرصيد',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editStock(item, quantity ?? 0),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
