import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../providers/core_providers.dart';

Future<Map<String, int>?> showBuffetPicker(
  BuildContext context, {required String target, Map<String, int> existing = const {}}
) => showDialog<Map<String, int>>(
  context: context,
  builder: (_) => _BuffetPicker(target: target, existing: existing),
);

String _money(num value) => '${value.toStringAsFixed(2)} ج';

class _BuffetPicker extends ConsumerStatefulWidget {
  const _BuffetPicker({required this.target, required this.existing});
  final String target;
  final Map<String, int> existing;

  @override
  ConsumerState<_BuffetPicker> createState() => _BuffetPickerState();
}

class _BuffetPickerState extends ConsumerState<_BuffetPicker> {
  final _selected = <String, int>{};
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuItemsStreamProvider).valueOrNull ?? <MenuItemRow>[];
    final categories = ref.watch(buffetCategoriesStreamProvider).valueOrNull ?? <BuffetCategoryRow>[];
    final stock = {for (final row in ref.watch(inventoryStreamProvider).valueOrNull ?? <InventoryItemRow>[]) row.itemName: row.quantity};
    final existing = widget.existing;
    final filtered = menu.where((row) => (_category == null || row.categoryId == _category) &&
        row.itemName.toLowerCase().contains(_query)).toList();
    final count = _selected.values.fold<int>(0, (sum, value) => sum + value);
    final total = menu.fold<int>(0, (sum, item) => sum + item.price * (_selected[item.itemName] ?? 0));
    return AlertDialog(
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('اختار أصناف البوفيه'),
        Text(widget.target, style: Theme.of(context).textTheme.bodyMedium),
      ]),
      content: SizedBox(
        width: 620,
        height: 395,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(autofocus: true, decoration: const InputDecoration(
              labelText: 'ابحث عن صنف', prefixIcon: Icon(Icons.search),
            ), onChanged: (value) => setState(() => _query = value.trim().toLowerCase())),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip(null, 'الكل'),
                for (final row in categories) _chip(row.id, '${row.emoji} ${row.name}'),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(child: filtered.isEmpty
              ? const Center(child: Text('مفيش أصناف مطابقة. تقدر تضيف أصناف من الإعدادات.'))
              : ListView.builder(itemCount: filtered.length, itemBuilder: (context, index) {
                final row = filtered[index];
                final qty = _selected[row.itemName] ?? 0;
                final inStock = stock[row.itemName];
                final already = existing[row.itemName] ?? 0;
                return Card(
                  child: ListTile(
                    title: Text(row.itemName),
                    subtitle: Text('${_money(row.price)}${inStock == null ? '' : ' • متاح: ${(inStock - already).clamp(0, inStock)}'}'),
                    trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                      IconButton(tooltip: 'تقليل الكمية', onPressed: qty == 0 ? null : () => setState(() {
                        if (qty == 1) {
                          _selected.remove(row.itemName);
                        } else {
                          _selected[row.itemName] = qty - 1;
                        }
                      }), icon: const Icon(Icons.remove_circle_outline)),
                      SizedBox(width: 28, child: Text('$qty', textAlign: TextAlign.center)),
                      IconButton(tooltip: 'زيادة الكمية', onPressed: inStock != null && qty + already >= inStock
                          ? null : () => setState(() => _selected[row.itemName] = qty + 1),
                          icon: const Icon(Icons.add_circle_outline)),
                    ]),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton.icon(
          onPressed: count == 0 ? null : () => Navigator.pop(context, _selected),
          icon: const Icon(Icons.check),
          label: Text('إضافة $count • ${_money(total)}'),
        ),
      ],
    );
  }

  Widget _chip(String? category, String label) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 6),
    child: ChoiceChip(label: Text(label), selected: _category == category,
      onSelected: (_) => setState(() => _category = category)),
  );
}
