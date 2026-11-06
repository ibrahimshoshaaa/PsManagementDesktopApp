import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';

import '../devices/devices_screen.dart';
import '../drink_tables/drink_tables_screen.dart';
import '../local_orders/local_orders_screen.dart';
import '../shifts/shift_screen.dart';
import '../tables/tables_screen.dart';
import '../../core/theme/app_colors.dart';

class CashierWorkspace extends ConsumerWidget {
  const CashierWorkspace({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).valueOrNull;
    final games = config?.gameTablesEnabled ?? true;
    final drinks = config?.drinkTablesEnabled ?? true;
    final items = [
      (const Tab(text: 'الأجهزة', icon: Icon(Icons.sports_esports)), const DevicesScreen()),
      if (games) (const Tab(text: 'التربيزات', icon: Icon(Icons.table_bar)), const TablesScreen()),
      if (drinks) (const Tab(text: 'المشروبات', icon: Icon(Icons.local_cafe)), const DrinkTablesScreen()),
      (const Tab(text: 'الطلبات', icon: Icon(Icons.receipt_long)), const LocalOrdersScreen()),
      (const Tab(text: 'الشيفت', icon: Icon(Icons.badge_outlined)), const ShiftScreen()),
    ];
    return DefaultTabController(
      key: ValueKey((games, drinks)),
      length: items.length,
      child: Column(children: [
        Material(
          color: AppColors.sidebar,
          child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start,
            padding: const EdgeInsetsDirectional.only(start: 14), tabs: [for (final item in items) item.$1]),
        ),
        Expanded(child: TabBarView(children: [for (final item in items) item.$2])),
      ]),
    );
  }
}
