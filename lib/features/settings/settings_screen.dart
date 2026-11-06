import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/core_providers.dart';
import 'settings_controller.dart';
import 'menu_item_dialog.dart';
import '../shared/operation_dialog.dart';
import '../../data/local/database.dart';
import '../cashier/cashiers_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selected = 0;
  static const _items = [
    ('عام ونسخ احتياطي', Icons.settings_outlined, _GeneralTab()),
    ('الأجهزة والتربيزات', Icons.sports_esports_outlined, _DevicesTablesTab()),
    ('الأسعار', Icons.payments_outlined, _PricesTab()),
    ('حسابات الكاشير', Icons.manage_accounts_outlined, CashiersScreen()),
    ('المنيو والأقسام', Icons.restaurant_menu, _MenuTab()),
    ('المخزون', Icons.inventory_2_outlined, _InventoryTab()),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, limits) {
    final item = _items[_selected];
    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
        child: Text(item.$1, style: Theme.of(context).textTheme.titleLarge)),
      Expanded(child: KeyedSubtree(key: ValueKey(_selected), child: item.$3)),
    ]);
    if (limits.maxWidth < 760) {
      return Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: DropdownButtonFormField<int>(value: _selected, isExpanded: true,
            decoration: const InputDecoration(labelText: 'قسم الإعدادات'),
            items: [for (var i = 0; i < _items.length; i++) DropdownMenuItem(value: i, child: Text(_items[i].$1))],
            onChanged: (value) { if (value != null) setState(() => _selected = value); }),
        ),
        Expanded(child: content),
      ]);
    }
    return Row(children: [
      SizedBox(width: 220, child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (var i = 0; i < _items.length; i++) ListTile(
            selected: _selected == i,
            selectedTileColor: AppColors.card2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: Icon(_items[i].$2, size: 20),
            title: Text(_items[i].$1),
            onTap: () => setState(() => _selected = i),
          ),
        ],
      )),
      const VerticalDivider(width: 1),
      Expanded(child: content),
    ]);
  });
}

// ═══════════════════════════════════════════════════════════════ عام ═════

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).valueOrNull;
    if (config == null) return const Center(child: CircularProgressIndicator());
    final controller = ref.read(settingsControllerProvider);
    final nameController = TextEditingController(text: config.shopName);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم المحل'),
          onSubmitted: controller.updateShopName,
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          title: const Text('نظام الماتش', style: TextStyle(color: Colors.white)),
          subtitle: const Text('سعر ثابت منفصل للماتشات التنافسية', style: TextStyle(color: Colors.white38)),
          value: config.matchEnabled,
          onChanged: controller.setMatchEnabled,
        ),
        SwitchListTile(
          title: const Text('نظام الشحن', style: TextStyle(color: Colors.white)),
          subtitle: const Text('كروت شحن ورصيد للعملاء', style: TextStyle(color: Colors.white38)),
          value: config.rechargeEnabled,
          onChanged: controller.setRechargeEnabled,
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => _showChangePasswordDialog(context, controller),
          icon: const Icon(Icons.lock_reset),
          label: const Text('تغيير كلمة سر الأدمن'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _backup(context, ref),
          icon: const Icon(Icons.save_alt),
          label: const Text('حفظ نسخة احتياطية من البيانات'),
        ),
      ],
    );
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    try {
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final destination = await getSaveLocation(
        suggestedName: 'PS-Backup-$stamp.sqlite',
        acceptedTypeGroups: const [XTypeGroup(label: 'SQLite', extensions: ['sqlite'])],
      );
      if (destination == null || !context.mounted) return;
      if (await File(destination.path).exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختار اسم ملف جديد للنسخة الاحتياطية.')));
        }
        return;
      }
      if (!context.mounted) return;
      await ref.read(databaseProvider).customStatement('VACUUM INTO ?', [destination.path]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ نسخة احتياطية محلية')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ النسخة الاحتياطية')));
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context, SettingsController controller) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('كلمة سر جديدة'),
        content: TextField(controller: passwordController, obscureText: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (passwordController.text.isNotEmpty) controller.changeAdminPassword(passwordController.text);
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════ الأجهزة والتربيزات ═════

class _DevicesTablesTab extends ConsumerWidget {
  const _DevicesTablesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesStreamProvider).valueOrNull ?? [];
    final tables = ref.watch(gameTablesStreamProvider).valueOrNull ?? [];
    final drinkTables = ref.watch(drinkTablesStreamProvider).valueOrNull ?? [];
    final controller = ref.read(settingsControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionHeader(
          title: 'الأجهزة (${devices.length})',
          onAdd: () => _showAddDeviceDialog(context, controller),
        ),
        ...devices.map((d) => ListTile(
              leading: Icon(d.deviceType == 'ps5' ? Icons.videogame_asset : Icons.sports_esports, color: Colors.white54),
              title: Text(d.displayName, style: const TextStyle(color: Colors.white)),
              onTap: () => _rename(context, d.displayName, (name) => controller.renameDevice(d.deviceId, name)),
              subtitle: Text(d.deviceType.toUpperCase(), style: const TextStyle(color: Colors.white38)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                onPressed: () => _confirm(context, d.displayName, () => controller.removeDevice(d.deviceId)),
              ),
            )),
        const SizedBox(height: 24),
        _SectionHeader(title: 'التربيزات (${tables.length})', onAdd: () => _showAddTableDialog(context, controller)),
        ...tables.map((t) => ListTile(
              leading: const Icon(Icons.table_bar, color: Colors.white54),
              title: Text(t.name, style: const TextStyle(color: Colors.white)),
              onTap: () => _editTable(context, controller, t),
              subtitle: Text('${t.tableType == 'billiard' ? 'بلياردو' : 'بينج'} · ${t.rate} ج/ساعة · ${t.gamePrice} ج/لعبة', style: const TextStyle(color: Colors.white38)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                onPressed: () => _confirm(context, t.name, () => controller.removeTable(t.tableId)),
              ),
            )),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'تربيزات المشروبات (${drinkTables.length})',
          onAdd: () => _showAddDrinkTableDialog(context, controller),
        ),
        ...drinkTables.map((t) => ListTile(
              leading: const Icon(Icons.local_cafe, color: Colors.white54),
              title: Text(t.name, style: const TextStyle(color: Colors.white)),
              onTap: () => _rename(context, t.name, (name) => controller.renameDrinkTable(t.tableId, name)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                onPressed: () => _confirm(context, t.name, () => controller.removeDrinkTable(t.tableId)),
              ),
            )),
      ],
    );
  }

  Future<void> _confirm(BuildContext context, String name, Future<void> Function() remove) =>
    showOperationDialog(context, title: 'حذف $name؟', action: 'تأكيد الحذف',
      fields: const [Text('الفواتير القديمة هتفضل محفوظة في السجل.')], save: remove);

  Future<void> _rename(BuildContext context, String previous, Future<void> Function(String) save) {
    var name = previous;
    return showOperationDialog(context, title: 'تعديل الاسم', action: 'حفظ الاسم',
      fields: [TextFormField(initialValue: previous, autofocus: true,
        decoration: const InputDecoration(labelText: 'الاسم'),
        validator: (value) => value == null || value.trim().isEmpty ? 'اكتب الاسم' : null,
        onChanged: (value) => name = value.trim())],
      save: () => save(name));
  }

  Future<void> _editTable(BuildContext context, SettingsController controller, GameTableRow row) {
    var name = row.name, rate = '${row.rate}', game = '${row.gamePrice}';
    Widget number(String label, String value, ValueChanged<String> update) => TextFormField(
      initialValue: value, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label),
      validator: (value) {
        final number = int.tryParse(value?.trim() ?? '');
        return number == null || number < 0 ? 'اكتب سعرًا صحيحًا' : null;
      }, onChanged: (value) => update(value.trim()),
    );
    return showOperationDialog(context, title: 'تعديل التربيزة', action: 'حفظ التعديلات', fields: [
      TextFormField(initialValue: name, decoration: const InputDecoration(labelText: 'الاسم'),
        validator: (value) => value == null || value.trim().isEmpty ? 'اكتب الاسم' : null,
        onChanged: (value) => name = value.trim()),
      number('سعر الساعة', rate, (value) => rate = value),
      number('سعر اللعبة', game, (value) => game = value),
    ], save: () => controller.updateGameTable(row.tableId, name: name, rate: int.parse(rate), gamePrice: int.parse(game)));
  }

  void _showAddDeviceDialog(BuildContext context, SettingsController controller) {
    final nameController = TextEditingController();
    String type = 'ps4';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('جهاز جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'ps4', label: Text('PS4')), ButtonSegment(value: 'ps5', label: Text('PS5'))],
                selected: {type},
                onSelectionChanged: (s) => setState(() => type = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                controller.addDevice(displayName: nameController.text.trim(), deviceType: type);
                Navigator.pop(context);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTableDialog(BuildContext context, SettingsController controller) {
    final nameController = TextEditingController();
    final rateController = TextEditingController();
    final gamePriceController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تربيزة جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 12),
            TextField(controller: rateController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الساعة')),
            const SizedBox(height: 12),
            TextField(controller: gamePriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر اللعبة (اختياري)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              controller.addTable(
                name: nameController.text.trim(),
                rate: int.tryParse(rateController.text) ?? 0,
                gamePrice: int.tryParse(gamePriceController.text) ?? 0,
              );
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showAddDrinkTableDialog(BuildContext context, SettingsController controller) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تربيزة مشروبات جديدة'),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              controller.addDrinkTable(name: nameController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════ الأسعار ═════

class _PricesTab extends ConsumerWidget {
  const _PricesTab();
  String _priceLabel(String key) => switch (key) {
    'ps4_normal' => 'PS4 • ساعة عادي',
    'ps4_multi' => 'PS4 • ساعة مالتي',
    'ps5_normal' => 'PS5 • ساعة عادي',
    'ps5_multi' => 'PS5 • ساعة مالتي',
    'match_ps4_normal' => 'PS4 • ماتش عادي',
    'match_ps4_multi' => 'PS4 • ماتش مالتي',
    'match_ps5_normal' => 'PS5 • ماتش عادي',
    'match_ps5_multi' => 'PS5 • ماتش مالتي',
    'ping_normal' => 'بينج • ساعة',
    'billiard_normal' => 'بلياردو • ساعة',
    'billiard_american' => 'بلياردو أمريكي • ساعة',
    _ => key,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = ref.watch(pricesStreamProvider).valueOrNull ?? [];
    final controller = ref.read(settingsControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: prices
          .map((p) => ListTile(
                title: Text(_priceLabel(p.priceKey), style: const TextStyle(color: Colors.white)),
                trailing: SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: p.amount.toString(),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(suffixText: 'ج'),
                    onFieldSubmitted: (v) {
                      final amount = int.tryParse(v);
                      if (amount != null && amount >= 0) controller.setPrice(p.priceKey, amount);
                    },
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════ الكاشيرز ═════

// ═══════════════════════════════════════════════════════════ المنيو ═════

class _MenuTab extends ConsumerWidget {
  const _MenuTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuItems = ref.watch(menuItemsStreamProvider).valueOrNull ?? [];
    final categories = ref.watch(buffetCategoriesStreamProvider).valueOrNull ?? [];
    final controller = ref.read(settingsControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionHeader(title: 'أصناف المنيو (${menuItems.length})', onAdd: () => showMenuItemDialog(context)),
        ...menuItems.map((m) => ListTile(
              title: Text(m.itemName, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                'بيع: ${m.price} ج${m.buyPrice != null ? " · شراء: ${m.buyPrice} ج" : ""}'
                ' · ${categories.where((row) => row.id == m.categoryId).firstOrNull?.name ?? 'بدون قسم'}',
              ),
              trailing: Wrap(children: [
                IconButton(
                  tooltip: 'تعديل الصنف',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showMenuItemDialog(context, item: m),
                ),
                IconButton(
                  tooltip: 'حذف الصنف',
                  icon: const Icon(Icons.delete_outline, color: AppColors.red),
                  onPressed: () => _confirmRemove(context, controller, m.itemName),
                ),
              ]),
            )),
        const SizedBox(height: 24),
        _SectionHeader(title: 'أقسام البوفيه (${categories.length})', onAdd: () => _showAddCategoryDialog(context, controller)),
        ...categories.map((c) => ListTile(
              leading: Text(c.emoji, style: const TextStyle(fontSize: 20)),
              title: Text(c.name, style: const TextStyle(color: Colors.white)),
            )),
      ],
    );
  }

  Future<void> _confirmRemove(BuildContext context, SettingsController controller, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('حذف $name من المنيو؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await controller.removeMenuItem(name);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حذف الصنف. اتأكد إنه مش على حساب جلسة مفتوحة.')),
        );
      }
    }
  }

  void _showAddCategoryDialog(BuildContext context, SettingsController controller) {
    final nameController = TextEditingController();
    final emojiController = TextEditingController(text: '🍽');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قسم بوفيه جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 12),
            TextField(controller: emojiController, decoration: const InputDecoration(labelText: 'إيموجي')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              final id = nameController.text.trim().toLowerCase().replaceAll(' ', '_');
              controller.addBuffetCategory(id: id, name: nameController.text.trim(), emoji: emojiController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════ المخزون ═════

class _InventoryTab extends ConsumerWidget {
  const _InventoryTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inventoryStreamProvider).valueOrNull ?? [];
    final menuItems = ref.watch(menuItemsStreamProvider).valueOrNull ?? [];
    final controller = ref.read(settingsControllerProvider);
    final trackedNames = items.map((i) => i.itemName).toSet();
    final untracked = menuItems.where((m) => !trackedNames.contains(m.itemName)).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ...items.map((i) => ListTile(
              title: Text(i.itemName, style: const TextStyle(color: Colors.white)),
              trailing: SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: i.quantity.toString(),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  onFieldSubmitted: (v) {
                    final qty = int.tryParse(v);
                    if (qty != null) controller.setInventoryQuantity(i.itemName, qty);
                  },
                ),
              ),
            )),
        if (untracked.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('أصناف من غير تتبع مخزون', style: TextStyle(color: Colors.white38))),
          ...untracked.map((m) => ListTile(
                title: Text(m.itemName, style: const TextStyle(color: Colors.white54)),
                trailing: TextButton(
                  onPressed: () => controller.setInventoryQuantity(m.itemName, 0),
                  child: const Text('ابدأ تتبع'),
                ),
              )),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════ Shared ═

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  const _SectionHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.accent), onPressed: onAdd),
      ],
    );
  }
}
