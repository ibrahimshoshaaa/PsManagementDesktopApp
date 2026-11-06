import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/remote/firebase_service.dart';
import 'customer.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> _customers = [];
  String _query = '';
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _busy = true);
    final data = await FirebaseService.get('customers');
    if (!mounted) return;
    setState(() {
      if (data is Map) {
        _customers = [
          for (final row in data.entries)
            if (row.value is Map) Customer.fromMap(row.key.toString(), row.value as Map),
        ]..sort((a, b) => b.lastVisit.compareTo(a.lastVisit));
      }
      _busy = false;
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _edit([Customer? customer]) async {
    var name = customer?.name ?? '';
    var phone = customer?.phone ?? '';
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(customer == null ? 'إضافة عميل' : 'تعديل بيانات العميل'),
        content: SizedBox(
          width: 360,
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                  onChanged: (value) => name = value.trim(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الموبايل'),
                  onChanged: (value) => phone = value.trim(),
                  validator: (value) {
                    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value?.trim() ?? '')) {
                      return 'اكتب رقم موبايل صحيح';
                    }
                    if (_customers.any((row) => row.phone == phone && row.id != customer?.id)) {
                      return 'الرقم موجود بالفعل';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(dialog, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (!mounted || saved != true) return;
    setState(() => _busy = true);
    final fields = {'name': name, 'phone': phone};
    final ok = customer == null
        ? await FirebaseService.push('customers', {
            ...fields,
            'visits': 0,
            'total_spent': 0,
            'last_visit': DateTime.now().toIso8601String(),
          }) != null
        : await FirebaseService.patch('customers/${customer.id}', fields);
    if (!mounted) return;
    if (!ok) _message('تعذر حفظ بيانات العميل. راجع الاتصال وحاول تاني.');
    await _reload();
  }

  Future<void> _delete(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('حذف العميل؟'),
        content: Text(customer.name.isEmpty ? customer.phone : customer.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('حذف')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    final ok = await FirebaseService.delete('customers/${customer.id}');
    if (!mounted) return;
    if (ok) {
      setState(() => _customers.removeWhere((row) => row.id == customer.id));
    } else {
      _message('تعذر حذف العميل.');
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _customers.where((row) =>
        row.name.toLowerCase().contains(_query) || row.phone.contains(_query)).toList();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'ابحث بالاسم أو الرقم',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(tooltip: 'تحديث', onPressed: _busy ? null : _reload, icon: const Icon(Icons.refresh)),
              FilledButton.icon(
                onPressed: _busy ? null : () => _edit(),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('إضافة عميل'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: visible.isEmpty
                ? Center(child: Text(_busy ? 'جاري تحميل العملاء…' : 'مفيش عملاء ظاهرين'))
                : ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final row = visible[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                          title: Text(row.name.isEmpty ? row.phone : row.name),
                          subtitle: Text('${row.phone}  •  ${row.visits} زيارة  •  ${row.totalSpent.toStringAsFixed(2)} ج'),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'نسخ الرقم',
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: row.phone));
                                  if (mounted) _message('تم نسخ الرقم');
                                },
                                icon: const Icon(Icons.copy),
                              ),
                              IconButton(tooltip: 'تعديل', onPressed: _busy ? null : () => _edit(row), icon: const Icon(Icons.edit_outlined)),
                              IconButton(tooltip: 'حذف', onPressed: _busy ? null : () => _delete(row), icon: const Icon(Icons.delete_outline)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
