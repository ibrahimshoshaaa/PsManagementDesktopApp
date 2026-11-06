import '../shared/screen_ui.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/core_providers.dart';
import '../settings/settings_controller.dart';

class CashiersScreen extends ConsumerWidget {
  const CashiersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashiers = ref.watch(cashiersStreamProvider).valueOrNull ?? [];
    final controller = ref.read(settingsControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ScreenIntro(
          icon: Icons.manage_accounts_outlined, title: 'حسابات الكاشير',
          description: '${cashiers.length} حساب • اضغط تعديل لتغيير الاسم أو كلمة السر.',
          actions: [
            FilledButton.icon(
              onPressed: () => _showAddDialog(context, controller),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('إضافة كاشير'),
            ),
          ],
        ),
        ...cashiers.map((c) => ListTile(
              leading: const Icon(Icons.person, color: Colors.white54),
              title: Text(c.name, style: const TextStyle(color: Colors.white)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'تعديل الاسم',
                    onPressed: () => _rename(context, controller, c.id, c.name),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  TextButton(
                    onPressed: () => _showChangePasswordDialog(context, controller, c.id),
                    child: const Text('كلمة سر جديدة'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.red),
                    onPressed: () => _delete(context, controller, c.id, c.name),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Future<void> _rename(BuildContext context, SettingsController controller, int id, String oldName) async {
    var name = oldName;
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('تعديل اسم الكاشير'),
        content: TextFormField(
          initialValue: oldName,
          autofocus: true,
          onChanged: (value) => name = value.trim(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () { if (name.isNotEmpty) Navigator.pop(dialog, name); },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (!context.mounted || result == null) return;
    await _run(context, () => controller.renameCashier(id, result));
  }

  Future<void> _delete(BuildContext context, SettingsController controller, int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('حذف حساب $name؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('حذف')),
        ],
      ),
    );
    if (context.mounted && confirmed == true) await _run(context, () => controller.removeCashier(id));
  }

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ التغيير. تأكد إن الاسم غير مكرر وإن شيفت الكاشير مقفول.')),
        );
      }
    }
  }

  Future<void> _showAddDialog(BuildContext context, SettingsController controller) async {
    var name = '';
    var password = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('كاشير جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(autofocus: true, onChanged: (value) => name = value.trim(),
                decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 12),
            TextField(obscureText: true, onChanged: (value) => password = value,
                decoration: const InputDecoration(labelText: 'كلمة السر')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (name.isNotEmpty && password.isNotEmpty) Navigator.pop(dialog, true);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (context.mounted && confirmed == true) {
      await _run(context, () => controller.addCashier(name: name, password: password));
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context, SettingsController controller, int id) async {
    var password = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('كلمة سر جديدة'),
        content: TextField(autofocus: true, obscureText: true, onChanged: (value) => password = value),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () { if (password.isNotEmpty) Navigator.pop(dialog, true); },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (context.mounted && confirmed == true) {
      await _run(context, () => controller.changeCashierPassword(id, password));
    }
  }
}
