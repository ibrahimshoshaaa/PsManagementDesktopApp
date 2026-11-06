import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import '../settings/settings_controller.dart';

final _soldTodayProvider = StreamProvider<List<DailyInventorySummaryRow>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.dailyInventorySummary).watch();
});

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

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuItemsStreamProvider).valueOrNull ?? [];
    final stock = {
      for (final row in ref.watch(inventoryStreamProvider).valueOrNull ?? <InventoryItemRow>[])
        row.itemName: row.quantity,
    };
    final sold = {
      for (final row in ref.watch(_soldTodayProvider).valueOrNull ?? <DailyInventorySummaryRow>[])
        row.itemName: row.quantitySold,
    };
    final items = {
      for (final row in menu) row.itemName,
      ...stock.keys,
      ...sold.keys,
    }.where((item) => item.toLowerCase().contains(_query)).toList()..sort();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
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
                ? const Center(child: Text('مفيش أصناف ظاهرة'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final quantity = stock[item];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
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
