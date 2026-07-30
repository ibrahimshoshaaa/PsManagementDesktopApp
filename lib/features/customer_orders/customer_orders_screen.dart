import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'customer_orders_controller.dart';

class CustomerOrdersScreen extends ConsumerStatefulWidget {
  const CustomerOrdersScreen({super.key});
  @override
  ConsumerState<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends ConsumerState<CustomerOrdersScreen> {
  List<CustomerOrder> _orders = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final orders = await ref.read(customerOrdersControllerProvider).fetch();
    if (mounted) setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = _orders.where((o) => o.status == 'pending').toList();
    final done = _orders.where((o) => o.status == 'done').toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('طلبات العملاء', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              if (done.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(customerOrdersControllerProvider).clearDone(_orders);
                    _load();
                  },
                  icon: const Icon(Icons.delete_sweep, color: Colors.white54),
                  label: const Text('مسح المنتهي'),
                ),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white54), onPressed: _load),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? const Center(child: Text('مفيش طلبات عملاء لسه', style: TextStyle(color: Colors.white38)))
                    : ListView(
                        children: [
                          ...pending.map((o) => _OrderCard(order: o, onLoaded: _load)),
                          if (done.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('منتهية', style: TextStyle(color: Colors.white38)),
                            ),
                            ...done.map((o) => _OrderCard(order: o, onLoaded: _load)),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final CustomerOrder order;
  final VoidCallback onLoaded;
  const _OrderCard({required this.order, required this.onLoaded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = order.status == 'pending';
    IconData icon;
    switch (order.deviceType) {
      case 'table':
        icon = Icons.table_bar;
        break;
      case 'drink_table':
        icon = Icons.local_cafe;
        break;
      default:
        icon = Icons.sports_esports;
    }

    return Card(
      color: isPending ? AppColors.card2 : AppColors.card,
      child: ListTile(
        leading: Icon(icon, color: isPending ? AppColors.amber : Colors.white24),
        title: Text('${order.deviceName} — ${order.orderItems.entries.map((e) => "${e.key} ×${e.value}").join("، ")}',
            style: TextStyle(color: isPending ? Colors.white : Colors.white38)),
        subtitle: Text(order.orderText, style: const TextStyle(color: Colors.white38)),
        trailing: isPending
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: AppColors.green),
                    onPressed: () async {
                      await ref.read(customerOrdersControllerProvider).markDone(order);
                      onLoaded();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.red),
                    onPressed: () async {
                      await ref.read(customerOrdersControllerProvider).delete(order.key);
                      onLoaded();
                    },
                  ),
                ],
              )
            : IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                onPressed: () async {
                  await ref.read(customerOrdersControllerProvider).delete(order.key);
                  onLoaded();
                },
              ),
      ),
    );
  }
}
