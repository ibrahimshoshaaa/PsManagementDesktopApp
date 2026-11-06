import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import 'settings_controller.dart';

Future<void> showMenuItemDialog(BuildContext context, {MenuItemRow? item}) =>
    showDialog<void>(context: context, builder: (_) => _MenuItemDialog(item: item));

class _MenuItemDialog extends ConsumerStatefulWidget {
  const _MenuItemDialog({this.item});
  final MenuItemRow? item;

  @override
  ConsumerState<_MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends ConsumerState<_MenuItemDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.itemName);
  late final _sale = TextEditingController(text: widget.item?.price.toString());
  late final _buy = TextEditingController(text: widget.item?.buyPrice?.toString());
  final _stock = TextEditingController(text: '0');
  bool _trackStock = true;
  late String? _category = widget.item?.categoryId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _sale.dispose();
    _buy.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = _name.text.trim();
      final items = ref.read(menuItemsStreamProvider).valueOrNull ?? [];
      if (widget.item == null && items.any((row) => row.itemName == name)) {
        setState(() => _error = 'فيه صنف بالاسم ده بالفعل');
        return;
      }
      await ref.read(settingsControllerProvider).saveMenuItem(
        name: name,
        price: int.parse(_sale.text.trim()),
        buyPrice: int.tryParse(_buy.text.trim()),
        openingStock: widget.item == null && _trackStock ? int.parse(_stock.text.trim()) : null,
        categoryId: _category,
        editing: widget.item != null,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error is StateError
          ? error.message.toString()
          : 'تعذر حفظ الصنف. راجع البيانات وحاول تاني.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _numeric(TextEditingController controller, String label, {bool required = false}) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label),
    validator: (input) {
      final text = input?.trim() ?? '';
      if (text.isEmpty && !required) return null;
      final amount = int.tryParse(text);
      return amount == null || amount < 0 ? 'اكتب رقمًا صحيحًا من صفر فأكثر' : null;
    },
  );

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    final categories = ref.watch(buffetCategoriesStreamProvider).valueOrNull ?? <BuffetCategoryRow>[];
    final category = categories.any((row) => row.id == _category) ? _category : null;
    return AlertDialog(
      title: Text(editing ? 'تعديل صنف البوفيه' : 'إضافة صنف للبوفيه'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(
                controller: _name,
                autofocus: !editing,
                readOnly: editing,
                decoration: const InputDecoration(labelText: 'اسم الصنف', prefixIcon: Icon(Icons.fastfood_outlined)),
                validator: (value) => value == null || value.trim().isEmpty ? 'اكتب اسم الصنف' : null,
              ),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _numeric(_sale, 'سعر البيع بالجنيه', required: true)),
                const SizedBox(width: 12),
                Expanded(child: _numeric(_buy, 'سعر الشراء (اختياري)')),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'القسم'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('بدون قسم')),
                  for (final row in categories)
                    DropdownMenuItem(value: row.id, child: Text('${row.emoji} ${row.name}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) => setState(() => _category = value?.isEmpty == true ? null : value),
              ),
              if (!editing) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تابع كمية الصنف في المخزون'),
                  value: _trackStock,
                  onChanged: (value) => setState(() => _trackStock = value),
                ),
                if (_trackStock) _numeric(_stock, 'الكمية الافتتاحية', required: true),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.red)),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.check), label: const Text('حفظ الصنف')),
      ],
    );
  }
}
