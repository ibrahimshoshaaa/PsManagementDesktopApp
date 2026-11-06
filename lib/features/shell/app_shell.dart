import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/core_providers.dart';
import '../devices/devices_screen.dart';
import '../devices/session_alerts.dart';
import '../dashboard/dashboard_screen.dart';
import '../tables/tables_screen.dart';
import '../drink_tables/drink_tables_screen.dart';
import '../shifts/shift_screen.dart';
import '../shifts/shift_history_screen.dart';
import '../recharge/recharge_screen.dart';
import '../tournaments/tournaments_screen.dart';
import '../history/history_screen.dart';
import '../debts/debts_screen.dart';
import '../expenses/expenses_screen.dart';
import '../settings/settings_screen.dart';
import '../audit/audit_logs_screen.dart';
import '../archive/archive_screen.dart';
import '../customers/customers_screen.dart';
import '../reports/daily_report_screen.dart';
import '../inventory/inventory_screen.dart';
import '../buffet/buffet_categories_screen.dart';
import '../cashier/cashiers_screen.dart';
import '../cashier/cashier_workspace.dart';
import '../local_orders/local_orders_screen.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final Widget screen;
  final bool adminOnly;
  const _NavItem(this.label, this.icon, this.screen, {this.adminOnly = false});
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.onManageLicense});

  final VoidCallback? onManageLicense;
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final config = ref.watch(appConfigProvider).valueOrNull;
    final isAdmin = session.role == UserRole.admin;

    final items = <_NavItem>[
      if (!isAdmin)
        const _NavItem('مساحة الكاشير', Icons.point_of_sale, CashierWorkspace()),
      const _NavItem('الأجهزة', Icons.sports_esports, DevicesScreen()),
      const _NavItem('التربيزات', Icons.table_bar, TablesScreen()),
      const _NavItem('المشروبات', Icons.local_cafe, DrinkTablesScreen()),
      const _NavItem('الشيفت', Icons.badge, ShiftScreen()),
      const _NavItem('سجل الشيفتات', Icons.work_history_outlined, ShiftHistoryScreen(), adminOnly: true),
      const _NavItem('طلبات البوفيه', Icons.receipt_outlined, LocalOrdersScreen()),
      _NavItem('لوحة التحكم', Icons.dashboard, const DashboardScreen(), adminOnly: true),
      const _NavItem('تقرير اليوم', Icons.analytics_outlined, DailyReportScreen(), adminOnly: true),
      const _NavItem('العملاء', Icons.people_outline, CustomersScreen(), adminOnly: true),
      const _NavItem('المخزون', Icons.inventory_2_outlined, InventoryScreen(), adminOnly: true),
      _NavItem('السجل', Icons.receipt_long, const HistoryScreen(), adminOnly: true),
      if (config?.matchEnabled ?? true)
        const _NavItem('البطولات', Icons.emoji_events, TournamentsScreen()),
      const _NavItem('المديونيات', Icons.money_off, DebtsScreen()),
      const _NavItem('المصروفات', Icons.payments, ExpensesScreen()),
      if (config?.rechargeEnabled ?? false)
        const _NavItem('الشحن', Icons.battery_charging_full, RechargeScreen()),
      _NavItem('الأرشيف', Icons.archive_outlined, const ArchiveScreen(), adminOnly: true),
      _NavItem('سجل التدقيق', Icons.fact_check, const AuditLogsScreen(), adminOnly: true),
      const _NavItem('أقسام البوفيه', Icons.category_outlined, BuffetCategoriesScreen(), adminOnly: true),
      const _NavItem('حسابات الكاشير', Icons.manage_accounts_outlined, CashiersScreen(), adminOnly: true),
      _NavItem('الإعدادات', Icons.settings, const SettingsScreen(), adminOnly: true),
    ];

    final visibleItems = items.where((i) => !i.adminOnly || isAdmin).toList();
    final index = visibleItems.indexWhere((item) => item.label == _selected);
    final selected = index < 0 ? 0 : index;
    final current = visibleItems[selected];
    final compact = MediaQuery.sizeOf(context).width < 1050;

    return SessionAlerts(child: Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _Sidebar(
            items: visibleItems,
            selected: selected,
            compact: compact,
            onSelect: (i) => setState(() => _selected = visibleItems[i].label),
            shopName: config?.shopName ?? '',
            session: session,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 16),
                  decoration: const BoxDecoration(
                    color: AppColors.sidebar,
                    border: Border(bottom: BorderSide(color: AppColors.divider)),
                  ),
                  child: Row(
                    children: [
                      Icon(current.icon, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(current.label, style: Theme.of(context).textTheme.titleLarge),
                      ),
                      const SizedBox(width: 12),
                      Text(isAdmin ? 'مدير المحل' : session.cashierName ?? 'الكاشير'),
                      if (isAdmin && widget.onManageLicense != null)
                        IconButton(
                          tooltip: 'الترخيص والتجديد',
                          onPressed: widget.onManageLicense,
                          icon: const Icon(Icons.vpn_key_outlined),
                        ),
                    ],
                  ),
                ),
                Expanded(child: KeyedSubtree(key: ValueKey(current.label), child: current.screen)),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

class _Sidebar extends ConsumerWidget {
  final List<_NavItem> items;
  final int selected;
  final bool compact;
  final ValueChanged<int> onSelect;
  final String shopName;
  final SessionState session;

  const _Sidebar({
    required this.items,
    required this.selected,
    required this.compact,
    required this.onSelect,
    required this.shopName,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: compact ? 68 : 220,
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.sports_esports, color: AppColors.accent, size: 32),
          const SizedBox(height: 8),
          if (!compact) Text(shopName.isEmpty ? 'PS Management' : shopName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (!compact) Text(
            session.role == UserRole.admin ? 'أدمن' : (session.cashierName ?? ''),
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final isSelected = i == selected;
                return Tooltip(
                  message: item.label,
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  child: Material(
                    color: isSelected ? AppColors.sidebarSelected : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onSelect(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            Icon(item.icon, size: 20, color: isSelected ? AppColors.accent : Colors.white54),
                            if (!compact) const SizedBox(width: 12),
                            if (!compact) Expanded(
                              child: Text(item.label,
                                  style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: compact
                ? IconButton(
                    tooltip: 'تسجيل خروج',
                    onPressed: () => ref.read(sessionProvider.notifier).logout(),
                    icon: const Icon(Icons.logout, color: AppColors.red),
                  )
                : TextButton.icon(
              onPressed: () => ref.read(sessionProvider.notifier).logout(),
              icon: const Icon(Icons.logout, size: 18, color: AppColors.red),
              label: const Text('تسجيل خروج', style: TextStyle(color: AppColors.red)),
            ),
          ),
        ],
      ),
    );
  }
}
