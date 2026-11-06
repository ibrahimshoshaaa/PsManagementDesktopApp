import 'package:flutter/material.dart';

import '../devices/devices_screen.dart';
import '../drink_tables/drink_tables_screen.dart';
import '../local_orders/local_orders_screen.dart';
import '../shifts/shift_screen.dart';
import '../tables/tables_screen.dart';

class CashierWorkspace extends StatelessWidget {
  const CashierWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 5,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'الأجهزة', icon: Icon(Icons.sports_esports)),
              Tab(text: 'التربيزات', icon: Icon(Icons.table_bar)),
              Tab(text: 'المشروبات', icon: Icon(Icons.local_cafe)),
              Tab(text: 'الطلبات', icon: Icon(Icons.receipt_long)),
              Tab(text: 'الشيفت', icon: Icon(Icons.badge_outlined)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                DevicesScreen(),
                TablesScreen(),
                DrinkTablesScreen(),
                LocalOrdersScreen(),
                ShiftScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
