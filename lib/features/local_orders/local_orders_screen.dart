import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import '../devices/devices_controller.dart';
import '../drink_tables/drink_tables_controller.dart';
import '../tables/tables_controller.dart';

enum _TargetType { device, table, drinks }

typedef _Target = ({_TargetType type, int id, String name});

final _ordersProvider = StreamProvider.autoDispose<List<CustomerOrderRow>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.customerOrders)..orderBy([(row) => OrderingTerm.desc(row.rowId)])).watch();
});

Map<String, dynamic> _readOrder(String json) {
  try {
    final value = jsonDecode(json);
    return value is Map<String, dynamic> ? value : {};
  } on FormatException {
    return {};
  }
}

class LocalOrdersScreen extends ConsumerWidget {
  const LocalOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesStreamProvider).valueOrNull ?? [];
    final tables = ref.watch(gameTablesStreamProvider).valueOrNull ?? [];
    final drinks = ref.watch(drinkTablesStreamProvider).valueOrNull ?? [];
    final menu = ref.watch(menuItemsStreamProvider).valueOrNull ?? [];
    final targets = <_Target>[
      for (final device in devices)
        if (device.startTime != null)
          (type: _TargetType.device, id: device.deviceId, name: device.displayName),
      for (final table in tables)
        if (table.startTime != null)
          (type: _TargetType.table, id: table.tableId, name: table.name),
      for (final table in drinks)
        (type: _TargetType.drinks, id: table.tableId, name: table.name),
    ];
    final orders = ref.watch(_ordersProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text('الطلب بيتسجل على الحساب وقت إضافته.')),
              FilledButton.icon(
                onPressed: targets.isEmpty || menu.isEmpty ? null : () => _add(context, ref, targets, menu),
                icon: const Icon(Icons.add),
                label: const Text('طلب جديد'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (targets.isEmpty || menu.isEmpty)
            const Text('ابدأ جلسة أو أضف تربيزة مشروبات، وتأكد إن المنيو فيه أصناف.'),
          Expanded(
            child: orders.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('تعذر تحميل الطلبات')),
              data: (rows) => rows.isEmpty
                  ? const Center(child: Text('مفيش طلبات محلية لسه'))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final order = _readOrder(row.dataJson);
                        final done = order['delivered'] == true;
                        final items = order['items'];
                        final details = items is Map
                            ? items.entries.map((item) => '${item.key} × ${item.value}').join('، ')
                            : '';
                        return Card(
                          child: ListTile(
                            leading: Icon(done ? Icons.check_circle_outline : Icons.receipt_long_outlined),
                            title: Text(order['target']?.toString() ?? 'طلب ${row.rowId}'),
                            subtitle: Text(details),
                            trailing: done
                                ? const Text('تم التسليم')
                                : OutlinedButton(
                                    onPressed: () => _deliver(context, ref, row.rowId),
                                    child: const Text('تم التسليم'),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, List<_Target> targets, List<MenuItemRow> menu) async {
    final selection = await showDialog<(_Target, Map<String, int>)>(
      context: context,
      builder: (_) => _OrderDialog(targets: targets, menu: menu),
    );
    if (selection == null || !context.mounted) return;
    final (target, items) = selection;
    final db = ref.read(databaseProvider);
    final devices = ref.read(devicesControllerProvider);
    final tables = ref.read(tablesControllerProvider);
    final drinks = ref.read(drinkTablesControllerProvider);
    try {
      await db.transaction(() async {
        switch (target.type) {
          case _TargetType.device:
            final row = await (db.select(db.devices)..where((t) => t.deviceId.equals(target.id))).getSingle();
            if (row.startTime == null) throw StateError('Device session closed');
          case _TargetType.table:
            final row = await (db.select(db.gameTables)..where((t) => t.tableId.equals(target.id))).getSingle();
            if (row.startTime == null) throw StateError('Table session closed');
          case _TargetType.drinks:
            await (db.select(db.drinkTables)..where((t) => t.tableId.equals(target.id))).getSingle();
        }
        for (final item in items.entries) {
          switch (target.type) {
            case _TargetType.device:
              await devices.addOrder(target.id, item.key, item.value);
            case _TargetType.table:
              await tables.addOrder(target.id, item.key, item.value);
            case _TargetType.drinks:
              await drinks.addOrder(target.id, item.key, item.value);
          }
        }
        await db.into(db.customerOrders).insert(CustomerOrdersCompanion.insert(
          dataJson: jsonEncode({
            'target': target.name,
            'items': items,
            'createdAt': DateTime.now().toIso8601String(),
            'delivered': false,
          }),
        ));
      });
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تسجيل الطلب. تأكد إن الجلسة لسه مفتوحة.')),
        );
      }
    }
  }

  Future<void> _deliver(BuildContext context, WidgetRef ref, int id) async {
    final db = ref.read(databaseProvider);
    try {
      await db.transaction(() async {
        final row = await (db.select(db.customerOrders)..where((t) => t.rowId.equals(id))).getSingle();
        final order = _readOrder(row.dataJson)..['delivered'] = true;
        await (db.update(db.customerOrders)..where((t) => t.rowId.equals(id)))
            .write(CustomerOrdersCompanion(dataJson: Value(jsonEncode(order))));
      });
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحديث حالة التسليم')));
      }
    }
  }
}

class _OrderDialog extends StatefulWidget {
  const _OrderDialog({required this.targets, required this.menu});

  final List<_Target> targets;
  final List<MenuItemRow> menu;

  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  late _Target _target = widget.targets.first;
  final _items = <String, int>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('طلب بوفيه جديد'),
      content: SizedBox(
        width: 480,
        height: 380,
        child: Column(
          children: [
            DropdownButtonFormField<_Target>(
              value: _target,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'الجهاز أو التربيزة'),
              items: [
                for (final target in widget.targets)
                  DropdownMenuItem(value: target, child: Text(target.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) { if (value != null) setState(() => _target = value); },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: widget.menu.length,
                itemBuilder: (context, index) {
                  final item = widget.menu[index];
                  final count = _items[item.itemName] ?? 0;
                  return ListTile(
                    title: Text(item.itemName),
                    subtitle: Text('${item.price} ج'),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'تقليل الكمية',
                          onPressed: count == 0 ? null : () => setState(() {
                            if (count == 1) {
                              _items.remove(item.itemName);
                            } else {
                              _items[item.itemName] = count - 1;
                            }
                          }),
                          icon: const Icon(Icons.remove),
                        ),
                        Text('$count'),
                        IconButton(
                          tooltip: 'زيادة الكمية',
                          onPressed: () => setState(() => _items[item.itemName] = count + 1),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: _items.isEmpty ? null : () => Navigator.pop(context, (_target, Map<String, int>.of(_items))),
          child: const Text('تسجيل الطلب وإضافته للحساب'),
        ),
      ],
    );
  }
}
