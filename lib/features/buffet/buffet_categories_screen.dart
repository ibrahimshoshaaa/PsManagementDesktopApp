import '../shared/screen_ui.dart';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import '../settings/settings_controller.dart';

class BuffetCategoriesScreen extends ConsumerWidget {
  const BuffetCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(buffetCategoriesStreamProvider);
    final items = ref.watch(menuItemsStreamProvider).valueOrNull ?? [];
    return categories.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('تعذر تحميل أقسام البوفيه')),
      data: (rows) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ScreenIntro(
            icon: Icons.category_outlined, title: 'أقسام المنيو',
            description: 'الأقسام بتظهر للكاشير وقت اختيار أصناف الطلب.',
            actions: [
              FilledButton.icon(
                onPressed: () => _edit(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('إضافة قسم'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty) const ScreenEmpty(icon: Icons.category_outlined, title: 'مفيش أقسام', hint: 'أضف قسم زي مشروبات أو سناكس عشان ترتّب الأصناف.'),
          for (final row in rows)
            Card(
              child: ListTile(
                leading: Text(row.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(row.name),
                subtitle: Text('${items.where((item) => item.categoryId == row.id).length} صنف'),
                trailing: Wrap(
                  children: [
                    IconButton(tooltip: 'تعديل القسم', icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(context, ref, row)),
                    IconButton(tooltip: 'حذف القسم', icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, ref, row)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, [BuffetCategoryRow? category]) async {
    var name = category?.name ?? '';
    var emoji = category?.emoji ?? '🍽';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(category == null ? 'إضافة قسم' : 'تعديل القسم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(initialValue: name, autofocus: true,
                decoration: const InputDecoration(labelText: 'اسم القسم'),
                onChanged: (value) => name = value.trim()),
            const SizedBox(height: 12),
            TextFormField(initialValue: emoji, maxLength: 12,
                decoration: const InputDecoration(labelText: 'الرمز'),
                onChanged: (value) => emoji = value.trim()),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () { if (name.isNotEmpty) Navigator.pop(dialog, true); },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    try {
      final symbol = emoji.isEmpty ? '🍽' : emoji;
      if (category == null) {
        await ref.read(settingsControllerProvider).addBuffetCategory(
          id: const Uuid().v4(), name: name, emoji: symbol,
        );
      } else {
        final db = ref.read(databaseProvider);
        await (db.update(db.buffetCategories)..where((row) => row.id.equals(category.id)))
            .write(BuffetCategoriesCompanion(name: Value(name), emoji: Value(symbol)));
      }
    } catch (_) {
      if (context.mounted) _error(context);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, BuffetCategoryRow category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('حذف قسم ${category.name}؟'),
        content: const Text('الأصناف الموجودة فيه هتفضل في المنيو من غير قسم.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('حذف')),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    try {
      final db = ref.read(databaseProvider);
      await db.transaction(() async {
        await (db.update(db.menuItems)..where((row) => row.categoryId.equals(category.id)))
            .write(const MenuItemsCompanion(categoryId: Value(null)));
        await (db.delete(db.buffetCategories)..where((row) => row.id.equals(category.id))).go();
      });
    } catch (_) {
      if (context.mounted) _error(context);
    }
  }

  void _error(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر حفظ تغيير القسم')),
    );
  }
}
