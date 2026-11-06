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
import '../shared/screen_ui.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final Widget screen;
  final bool adminOnly;
  const _NavItem(this.label, this.icon, this.screen, {this.adminOnly = false});
}

const _sections = <(String, List<String>)>[
  ('التشغيل', ['مساحة الكاشير', 'الأجهزة', 'التربيزات', 'المشروبات', 'طلبات البوفيه', 'الشيفت', 'البطولات', 'الشحن']),
  ('الحسابات', ['لوحة التحكم', 'تقرير اليوم', 'السجل', 'المديونيات', 'المصروفات', 'سجل الشيفتات']),
  ('إدارة المحل', ['العملاء', 'المخزون', 'أقسام البوفيه', 'حسابات الكاشير', 'الأرشيف', 'سجل التدقيق', 'الإعدادات']),
];

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
      if (config?.gameTablesEnabled ?? true)
        const _NavItem('التربيزات', Icons.table_bar, TablesScreen()),
      if (config?.drinkTablesEnabled ?? true)
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

    final allowed = {for (final item in items) if (!item.adminOnly || isAdmin) item.label: item};
    final visibleItems = [for (final section in _sections)
      for (final label in section.$2) if (allowed.containsKey(label)) allowed[label]!];
    final index = visibleItems.indexWhere((item) => item.label == _selected);
    final selected = index < 0 ? 0 : index;
    final current = visibleItems[selected];
    final compact = MediaQuery.sizeOf(context).width < 980;

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
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 16),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
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
                      if (!compact) Chip(
                        avatar: Icon(isAdmin ? Icons.admin_panel_settings_outlined : Icons.badge_outlined, size: 16),
                        label: Text(isAdmin ? 'مدير المحل' : session.cashierName ?? 'الكاشير'),
                      ),
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

  const _Sidebar({
    required this.items,
    required this.selected,
    required this.compact,
    required this.onSelect,
    required this.shopName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: compact ? 70 : 232,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: BorderDirectional(end: BorderSide(color: AppColors.divider)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 17),
          child: Row(children: [
            const ScreenIcon(Icons.sports_esports_outlined),
            if (!compact) ...[
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(shopName.isEmpty ? 'PS Management' : shopName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const Text('إدارة المحل • أوفلاين', style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ])),
            ],
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(9, 8, 9, 12), children: [
          for (final section in _sections)
            if (items.any((item) => section.$2.contains(item.label))) ...[
              if (!compact) Padding(
                padding: const EdgeInsets.fromLTRB(11, 12, 11, 5),
                child: Text(section.$1, style: Theme.of(context).textTheme.bodySmall),
              ) else const SizedBox(height: 6),
              for (var i = 0; i < items.length; i++)
                if (section.$2.contains(items[i].label)) _item(context, items[i], i),
            ],
        ])),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(10),
          child: compact
              ? IconButton(tooltip: 'تسجيل خروج', icon: const Icon(Icons.logout, color: AppColors.red),
                  onPressed: () => ref.read(sessionProvider.notifier).logout())
              : TextButton.icon(icon: const Icon(Icons.logout, color: AppColors.red, size: 18),
                  label: const Text('تسجيل خروج'),
                  onPressed: () => ref.read(sessionProvider.notifier).logout()),
        ),
      ]),
    );
  }

  Widget _item(BuildContext context, _NavItem item, int index) {
    final active = selected == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: item.label,
        child: Semantics(
          selected: active,
          child: Material(
            color: active ? AppColors.sidebarSelected : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () => onSelect(index),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 41),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
                    Icon(item.icon, size: 20, color: active ? AppColors.accent : AppColors.muted),
                    if (!compact) ...[
                      const SizedBox(width: 11),
                      Expanded(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: active ? AppColors.ink : AppColors.muted,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500))),
                      if (active) const Icon(Icons.chevron_left, size: 15, color: AppColors.accent),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
