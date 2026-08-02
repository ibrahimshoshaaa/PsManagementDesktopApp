import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/core_providers.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('الإعدادات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'عام'),
              Tab(text: 'الأجهزة والتربيزات'),
              Tab(text: 'الأسعار'),
              Tab(text: 'الكاشيرز'),
              Tab(text: 'المنيو'),
              Tab(text: 'المخزون'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _GeneralTab(),
                _DevicesTablesTab(),
                _PricesTab(),
                _CashiersTab(),
                _MenuTab(),
                _InventoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
      ],
    );
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
              subtitle: Text(d.deviceType, style: const TextStyle(color: Colors.white38)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                onPressed: () => controller.removeDevice(d.deviceId),
              ),
            )),
        const SizedBox(height: 24),
        _SectionHeader(title: 'التربيزات (${tables.length})', onAdd: () => _showAddTableDialog(context, controller)),
        ...tables.map((t) => ListTile(
              leading: const Icon(Icons.table_bar, color: Colors.white54),
              title: Text(t.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('${t.tableType} · ${t.rate} ج/ساعة · ${t.gamePrice} ج/لعبة', style: const TextStyle(color: Colors.white38)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                onPressed: () => controller.removeTable(t.tableId),
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
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                onPressed: () => controller.removeDrinkTable(t.tableId),
              ),
            )),
      ],
    );
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
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = ref.watch(pricesStreamProvider).valueOrNull ?? [];
    final controller = ref.read(settingsControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: prices
          .map((p) => ListTile(
                title: Text(p.priceKey, style: const TextStyle(color: Colors.white)),
                trailing: SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: p.amount.toString(),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(suffixText: 'ج'),
                    onFieldSubmitted: (v) {
                      final amount = int.tryParse(v);
                      if (amount != null) controller.setPrice(p.priceKey, amount);
                    },
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════ الكاشيرز ═════

class _CashiersTab extends ConsumerWidget {
  const _CashiersTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashiers = ref.watch(cashiersStreamProvider).valueOrNull ?? [];
    final controller = ref.read(settingsControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionHeader(title: 'الكاشيرز (${cashiers.length})', onAdd: () => _showAddDialog(context, controller)),
        ...cashiers.map((c) => ListTile(
              leading: const Icon(Icons.person, color: Colors.white54),
              title: Text(c.name, style: const TextStyle(color: Colors.white)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _showChangePasswordDialog(context, controller, c.id),
                    child: const Text('كلمة سر جديدة'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.red),
                    onPressed: () => controller.removeCashier(c.id),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  void _showAddDialog(BuildContext context, SettingsController controller) {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('كاشير جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 12),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة السر')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty || passwordController.text.isEmpty) return;
              controller.addCashier(name: nameController.text.trim(), password: passwordController.text);
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, SettingsController controller, int id) {
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
              if (passwordController.text.isNotEmpty) controller.changeCashierPassword(id, passwordController.text);
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

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
        _SectionHeader(title: 'أصناف المنيو (${menuItems.length})', onAdd: () => _showAddItemDialog(context, controller, categories)),
        ...menuItems.map((m) => ListTile(
              title: Text(m.itemName, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                'بيع: ${m.price} ج${m.buyPrice != null ? " · شراء: ${m.buyPrice} ج" : ""}${m.categoryId != null ? " · ${m.categoryId}" : ""}',
                style: const TextStyle(color: Colors.white38),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                onPressed: () => controller.removeMenuItem(m.itemName),
              ),
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

  void _showAddItemDialog(BuildContext context, SettingsController controller, List categories) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final buyPriceController = TextEditingController();
    String? categoryId = categories.isNotEmpty ? categories.first.id as String : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('صنف جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
              const SizedBox(height: 12),
              TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر البيع')),
              const SizedBox(height: 12),
              TextField(controller: buyPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الشراء (اختياري)')),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: categoryId,
                  decoration: const InputDecoration(labelText: 'القسم'),
                  items: categories.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c.id as String, child: Text('${c.emoji} ${c.name}'))).toList(),
                  onChanged: (v) => setState(() => categoryId = v),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final price = int.tryParse(priceController.text);
                if (nameController.text.trim().isEmpty || price == null) return;
                controller.addMenuItem(
                  name: nameController.text.trim(),
                  price: price,
                  categoryId: categoryId,
                  buyPrice: int.tryParse(buyPriceController.text),
                );
                Navigator.pop(context);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
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
