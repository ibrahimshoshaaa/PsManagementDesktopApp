import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../data/remote/firebase_service.dart';
import '../../providers/core_providers.dart';
import '../devices/devices_controller.dart';
import '../tables/tables_controller.dart';
import '../drink_tables/drink_tables_controller.dart';

class CustomerOrder {
  final String key;
  final int deviceId;
  final String deviceName;
  final String deviceType; // device | table | drink_table
  final String orderText;
  final Map<String, int> orderItems;
  final int timestamp;
  final String status; // pending | done

  CustomerOrder({
    required this.key,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.orderText,
    required this.orderItems,
    required this.timestamp,
    required this.status,
  });

  factory CustomerOrder.fromJson(String key, Map<String, dynamic> v) => CustomerOrder(
        key: key,
        deviceId: (v['device_id'] as num?)?.toInt() ?? 0,
        deviceName: v['device_name']?.toString() ?? 'جهاز',
        deviceType: v['device_type']?.toString() ?? 'device',
        orderText: v['order_text']?.toString() ?? '',
        orderItems: v['order_items'] != null
            ? Map<String, int>.from((v['order_items'] as Map).map((k, val) => MapEntry(k.toString(), (val as num).toInt())))
            : {},
        timestamp: (v['timestamp'] as num?)?.toInt() ?? 0,
        status: v['status']?.toString() ?? 'pending',
      );
}

final customerOrdersControllerProvider = Provider<CustomerOrdersController>((ref) => CustomerOrdersController(ref));

class CustomerOrdersController {
  final Ref ref;
  CustomerOrdersController(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);

  Future<List<CustomerOrder>> fetch() async {
    final shopId = FirebaseService.currentShopId;
    if (shopId == null) return [];
    final data = await FirebaseService.get(FirebaseService.customerOrdersPath(shopId));
    if (data == null || data is! Map) return [];
    final list = data.entries
        .map((e) => CustomerOrder.fromJson(e.key.toString(), Map<String, dynamic>.from(e.value as Map)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// يطبّق أصناف الأوردر على الجهاز/التربيزة الصح، بنفس منطق الموبايل بالظبط
  /// (بحث بالاسم الأول، ثم fallback بالـ index).
  Future<void> _applyToTarget(CustomerOrder order) async {
    if (order.orderItems.isEmpty) return;

    if (order.deviceType == 'device') {
      final devices = await _db.select(_db.devices).get();
      DeviceRow? target;
      try {
        target = devices.firstWhere((d) => d.displayName == order.deviceName);
      } catch (_) {
        try {
          target = devices.firstWhere((d) => d.deviceId == order.deviceId);
        } catch (_) {}
      }
      if (target != null && target.startTime != null) {
        final controller = ref.read(devicesControllerProvider);
        for (final e in order.orderItems.entries) {
          await controller.addOrder(target.deviceId, e.key, e.value);
        }
      }
    } else if (order.deviceType == 'table') {
      final tables = await _db.select(_db.gameTables).get();
      GameTableRow? target;
      try {
        target = tables.firstWhere((t) => t.name == order.deviceName);
      } catch (_) {
        if (order.deviceId < tables.length) target = tables[order.deviceId];
      }
      if (target != null) {
        final controller = ref.read(tablesControllerProvider);
        for (final e in order.orderItems.entries) {
          await controller.addOrder(target.tableId, e.key, e.value);
        }
      }
    } else if (order.deviceType == 'drink_table') {
      final tables = await _db.select(_db.drinkTables).get();
      DrinkTableRow? target;
      try {
        target = tables.firstWhere((t) => t.name == order.deviceName);
      } catch (_) {
        if (order.deviceId < tables.length) target = tables[order.deviceId];
      }
      if (target != null) {
        final controller = ref.read(drinkTablesControllerProvider);
        for (final e in order.orderItems.entries) {
          await controller.addOrder(target.tableId, e.key, e.value);
        }
      }
    }
  }

  Future<void> markDone(CustomerOrder order) async {
    final shopId = FirebaseService.currentShopId;
    if (shopId == null) return;
    await _applyToTarget(order);
    await FirebaseService.set('${FirebaseService.customerOrdersPath(shopId)}/${order.key}/status', 'done');
  }

  Future<void> delete(String key) async {
    final shopId = FirebaseService.currentShopId;
    if (shopId == null) return;
    await FirebaseService.delete('${FirebaseService.customerOrdersPath(shopId)}/$key');
  }

  Future<void> clearDone(List<CustomerOrder> orders) async {
    final done = orders.where((o) => o.status == 'done');
    for (final o in done) {
      await delete(o.key);
    }
  }
}
