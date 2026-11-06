import 'dart:convert';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/device_logic.dart';
import '../../providers/core_providers.dart';
import 'devices_controller.dart';

Future<void> openDeviceSession(BuildContext context, DeviceRow device, {bool buffet = false}) =>
    showDialog<void>(
      context: context,
      builder: (_) => device.isActive
          ? _SessionDialog(deviceId: device.deviceId, openBuffet: buffet)
          : _StartDialog(device: device),
    );

final _customers = StreamProvider.autoDispose<List<LocalCustomer>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.localCustomers).watch();
});

String _money(num value) => '${value.toStringAsFixed(2)} ج';

class _StartDialog extends ConsumerStatefulWidget {
  const _StartDialog({required this.device});
  final DeviceRow device;

  @override
  ConsumerState<_StartDialog> createState() => _StartDialogState();
}

class _StartDialogState extends ConsumerState<_StartDialog> {
  final _minutes = TextEditingController(text: '60');
  String _mode = 'normal';
  bool _fixed = false;
  bool _match = false;
  bool _busy = false;
  int? _customer;
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final minutes = !_match && _fixed ? int.tryParse(_minutes.text.trim()) : null;
    if (!_match && _fixed && (minutes == null || minutes < 1 || minutes > 1440)) {
      setState(() => _error = 'اكتب مدة من دقيقة إلى ١٤٤٠ دقيقة');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(devicesControllerProvider);
      if (_match) {
        final recorded = await controller.recordMatch(widget.device.deviceId, _mode, customerId: _customer);
        if (!recorded) throw StateError('Unavailable');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الماتش في السجل')));
        }
      } else {
        await controller.start(widget.device.deviceId, mode: _mode, minutes: minutes, customerId: _customer);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تنفيذ العملية. راجع حالة الجهاز وحاول تاني.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prices = {for (final row in ref.watch(pricesStreamProvider).valueOrNull ?? <PriceRow>[]) row.priceKey: row.amount};
    final matchEnabled = ref.watch(appConfigProvider).valueOrNull?.matchEnabled ?? false;
    final customers = ref.watch(_customers).valueOrNull ?? <LocalCustomer>[];
    final type = widget.device.deviceType;
    int price(String mode) => _match
        ? widget.device.copyWith(mode: mode).matchPrice(prices)
        : prices['${type}_$mode'] ?? (type == 'ps5' ? 35 : 25);
    final selectedMinutes = int.tryParse(_minutes.text.trim()) ?? 0;

    return AlertDialog(
      title: _Heading(icon: Icons.sports_esports_outlined, title: widget.device.displayName, subtitle: 'بدء جلسة • ${type.toUpperCase()}'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (matchEnabled) ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.schedule), label: Text('جلسة بالوقت')),
                    ButtonSegment(value: true, icon: Icon(Icons.emoji_events_outlined), label: Text('ماتش بسعر ثابت')),
                  ],
                  selected: {_match},
                  onSelectionChanged: _busy ? null : (values) => setState(() => _match = values.single),
                ),
                const SizedBox(height: 18),
              ],
              const Text('نوع اللعب'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _ModeTile(
                  label: 'عادي', price: '${price('normal')} ج / ${_match ? 'ماتش' : 'ساعة'}',
                  icon: Icons.person_outline, selected: _mode == 'normal',
                  onTap: () => setState(() => _mode = 'normal'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _ModeTile(
                  label: 'مالتي', price: '${price('multi')} ج / ${_match ? 'ماتش' : 'ساعة'}',
                  icon: Icons.group_outlined, selected: _mode == 'multi',
                  onTap: () => setState(() => _mode = 'multi'),
                )),
              ]),
              if (!_match) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('جلسة بوقت محدد'),
                  subtitle: Text(_fixed ? 'البرنامج هينبّهك عند انتهاء الوقت' : 'العداد يبدأ ويحسب لحد ما تقفل الجلسة'),
                  value: _fixed,
                  onChanged: (value) => setState(() => _fixed = value),
                ),
                if (_fixed) ...[
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final preset in [15, 30, 60, 90, 120])
                        ChoiceChip(
                          label: Text('$preset د'),
                          selected: selectedMinutes == preset,
                          onSelected: (_) => setState(() => _minutes.text = '$preset'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _minutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'المدة بالدقائق'),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
              if (customers.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: customers.any((row) => row.id == _customer) ? _customer : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'العميل (اختياري)'),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('بدون عميل')),
                    for (final row in customers)
                      DropdownMenuItem(value: row.id, child: Text('${row.name} • ${row.phone}', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (value) => setState(() => _customer = value),
                ),
              ],
              if (_match || (_fixed && selectedMinutes > 0)) ...[
                const SizedBox(height: 16),
                Text(
                  _match ? 'سعر الماتش: ${_money(price(_mode))}' :
                      'تكلفة اللعب للمدة المختارة: ${_money(price(_mode) * selectedMinutes / 60)}',
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('رجوع')),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: Icon(_match ? Icons.emoji_events_outlined : Icons.play_arrow_rounded),
          label: Text(_match ? 'تسجيل الماتش' : 'تشغيل الجهاز'),
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.label, required this.price, required this.icon, required this.selected, required this.onTap});
  final String label, price;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF204344) : AppColors.card2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: selected ? AppColors.accent : Colors.white12),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: AppColors.accent),
            const Spacer(),
            if (selected) const Icon(Icons.check_circle, size: 18, color: AppColors.accent),
          ]),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Text(price, style: const TextStyle(color: Colors.white70)),
        ]),
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF204344), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: AppColors.accent),
    ),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    ])),
  ]);
}

class _SessionDialog extends ConsumerStatefulWidget {
  const _SessionDialog({required this.deviceId, required this.openBuffet});
  final int deviceId;
  final bool openBuffet;

  @override
  ConsumerState<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends ConsumerState<_SessionDialog> {
  bool _busy = false;
  bool _opened = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is StateError ? error.message.toString() : 'تعذر حفظ التغيير. حاول تاني.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(tickerProvider);
    final devices = ref.watch(devicesStreamProvider).valueOrNull ?? <DeviceRow>[];
    final device = devices.where((row) => row.deviceId == widget.deviceId).firstOrNull;
    if (device == null || !device.isActive) {
      return AlertDialog(
        title: const Text('الجلسة مقفولة'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع'))],
      );
    }
    if (widget.openBuffet && !_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _buffet(device); });
    }
    final controller = ref.read(devicesControllerProvider);
    final session = ref.watch(sessionProvider);
    final customer = ref.watch(_customers).valueOrNull
        ?.where((row) => row.id == device.localCustomerId).firstOrNull;
    final prices = {for (final row in ref.watch(pricesStreamProvider).valueOrNull ?? <PriceRow>[]) row.priceKey: row.amount};
    final menu = {for (final row in ref.watch(menuItemsStreamProvider).valueOrNull ?? <MenuItemRow>[]) row.itemName: row.price};
    final orders = Map<String, int>.from(jsonDecode(device.ordersJson) as Map);
    final playing = device.calculateTimePrice(prices);
    final buffet = device.buffetPrice(orders, menu);
    final total = playing + buffet;
    final mode = device.mode == 'multi' ? 'مالتي' : 'عادي';
    final color = device.countdownFinished ? AppColors.red : device.isPaused ? AppColors.amber : AppColors.accent;
    final status = device.countdownFinished ? 'انتهى الوقت' : device.isPaused ? 'متوقف مؤقتًا' : 'شغّال';
    final destinations = devices.where((row) => row.deviceId != device.deviceId && !row.isActive && row.deviceType == device.deviceType).toList();
    return AlertDialog(
      title: _Heading(icon: Icons.sports_esports_outlined, title: device.displayName,
          subtitle: '${device.deviceType.toUpperCase()} • $mode${customer == null ? '' : ' • ${customer.name}'}'),
      content: SizedBox(
        width: 670,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF173640), Color(0xFF172239)]),
                border: Border.all(color: color.withOpacity(.5)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(children: [
                Text('$status  •  ${device.isCountdown ? 'وقت محدد' : 'وقت مفتوح'}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(device.timerText(), textDirection: TextDirection.ltr, style: TextStyle(
                  fontSize: 54, height: 1.1, fontWeight: FontWeight.w700, color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _Amount(label: 'اللعب', value: playing)),
                  Expanded(child: _Amount(label: 'البوفيه', value: buffet)),
                  Expanded(child: _Amount(label: 'الإجمالي', value: total, highlighted: true)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _action(device.isPaused ? 'استكمال' : 'إيقاف مؤقت', device.isPaused ? Icons.play_arrow : Icons.pause, () => _run(
                () => device.isPaused ? controller.resume(device.deviceId) : controller.pause(device.deviceId),
              )),
              _action('تنبيه', Icons.alarm, () => _numberDialog(device, adjustment: false)),
              _action('تعديل الوقت', Icons.more_time, () => _numberDialog(device, adjustment: true)),
              _action(device.mode == 'multi' ? 'تحويل لعادي' : 'تحويل لمالتي', Icons.compare_arrows,
                  device.isPaused ? null : () => _run(() => controller.switchMode(device.deviceId))),
              _action('نقل الجلسة', Icons.swap_horiz, destinations.isEmpty ? null : () => _transfer(device, destinations)),
              _action('سجل الجلسة', Icons.history, () => _showLog(device)),
            ]),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.local_cafe_outlined, color: AppColors.orange),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('طلبات البوفيه', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                    FilledButton.tonalIcon(onPressed: _busy ? null : () => _buffet(device),
                      icon: const Icon(Icons.add_shopping_cart), label: const Text('إضافة طلب')),
                  ]),
                  if (orders.isEmpty) const Padding(
                    padding: EdgeInsets.only(top: 14), child: Text('مفيش طلبات على الجلسة دي'),
                  ),
                  for (final item in orders.entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item.key} × ${item.value}'),
                      subtitle: Text(_money((menu[item.key] ?? 0) * item.value)),
                      trailing: IconButton(
                        tooltip: 'إزالة قطعة',
                        onPressed: _busy ? null : () => _run(() => controller.addOrder(device.deviceId, item.key, -1)),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
        if (session.role == UserRole.admin)
          TextButton(onPressed: _busy ? null : () => _cancel(device),
              child: const Text('إلغاء بدون حساب', style: TextStyle(color: AppColors.red))),
        FilledButton.icon(
          onPressed: _busy ? null : () => _checkout(device),
          icon: const Icon(Icons.receipt_long),
          label: Text('حساب الجلسة • ${_money(total)}'),
        ),
      ],
    );
  }

  Widget _action(String label, IconData icon, VoidCallback? action) => OutlinedButton.icon(
    onPressed: _busy ? null : action, icon: Icon(icon, size: 18), label: Text(label),
  );

  Future<void> _buffet(DeviceRow device) async {
    final changes = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => _BuffetPicker(device: device),
    );
    if (!mounted || changes == null) return;
    await _run(() => ref.read(devicesControllerProvider).addOrders(
      device.deviceId, changes, expectedStartTime: device.startTime,
    ));
  }

  Future<void> _numberDialog(DeviceRow device, {required bool adjustment}) async {
    int? value = adjustment ? null : device.timerAlertMinutes;
    final result = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(adjustment ? 'إضافة أو خصم وقت' : 'ضبط تنبيه الجلسة'),
        content: TextFormField(
          initialValue: value?.toString(),
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: InputDecoration(labelText: adjustment ? 'مثال: 15 إضافة أو -15 خصم' : 'تنبيه بعد كام دقيقة من بداية اللعب؟'),
          onChanged: (text) => value = int.tryParse(text.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('رجوع')),
          if (!adjustment)
            TextButton(onPressed: () => Navigator.pop(dialog, 0), child: const Text('إلغاء التنبيه')),
          FilledButton(onPressed: () {
            final minutes = value;
            if (minutes != null && minutes != 0 && minutes.abs() <= 1440 && (adjustment || minutes > 0)) {
              Navigator.pop(dialog, minutes);
            }
          }, child: const Text('حفظ')),
        ],
      ),
    );
    if (!mounted || result == null) return;
    await _run(() {
      final controller = ref.read(devicesControllerProvider);
      return adjustment
          ? controller.adjustMinutes(device.deviceId, result)
          : controller.setTimerAlert(device.deviceId, result == 0 ? null : result);
    });
  }

  Future<void> _transfer(DeviceRow device, List<DeviceRow> destinations) async {
    final target = await showDialog<int>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('اختار جهاز متاح لنقل الجلسة'),
        children: [
          for (final row in destinations)
            SimpleDialogOption(onPressed: () => Navigator.pop(dialog, row.deviceId), child: Text(row.displayName)),
        ],
      ),
    );
    if (!mounted || target == null) return;
    await _run(() async {
      final moved = await ref.read(devicesControllerProvider).transferSession(device.deviceId, target);
      if (mounted && moved) Navigator.pop(context);
    });
  }

  void _showLog(DeviceRow device) {
    final entries = (jsonDecode(device.sessionLogJson) as List).whereType<Map>().toList().reversed.toList();
    showDialog<void>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('سجل الجلسة'),
      content: SizedBox(width: 420, child: entries.isEmpty
        ? const Text('لسه مفيش أحداث مسجلة للجلسة دي')
        : ListView.builder(shrinkWrap: true, itemCount: entries.length, itemBuilder: (_, index) {
          final entry = entries[index];
          final date = DateTime.tryParse(entry['date']?.toString() ?? '');
          final time = date == null ? '' : TimeOfDay.fromDateTime(date).format(dialog);
          return ListTile(title: Text(entry['note']?.toString() ?? ''), trailing: Text(time));
        })),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('رجوع'))],
    ));
  }

  Future<void> _cancel(DeviceRow device) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('إلغاء الجلسة بدون حساب؟'),
      content: const Text('الطلب والوقت هيتشالوا من الجلسة من غير حفظ فاتورة.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('رجوع')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('إلغاء الجلسة')),
      ],
    ));
    if (!mounted || confirmed != true) return;
    await _run(() async {
      await ref.read(devicesControllerProvider).cancel(device.deviceId);
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _checkout(DeviceRow device) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: Text('حساب ${device.displayName}؟'),
      content: const Text('هيتحفظ حساب اللعب والبوفيه في فاتورة واحدة.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('رجوع')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('حفظ الفاتورة')),
      ],
    ));
    if (!mounted || confirmed != true) return;
    await _run(() async {
      final cashier = ref.read(sessionProvider).cashierName ?? 'أدمن';
      final result = await ref.read(devicesControllerProvider).stop(device.deviceId, closedBy: cashier);
      if (!mounted || result == null) return;
      await showDialog<void>(context: context, builder: (dialog) => AlertDialog(
        title: const Text('الفاتورة اتحفظت'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _Amount(label: 'اللعب', value: result['time_cost'] as num),
          _Amount(label: 'البوفيه', value: result['buffet_cost'] as num),
          _Amount(label: 'الإجمالي', value: result['total'] as num, highlighted: true),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(dialog), child: const Text('تم'))],
      ));
      if (mounted) Navigator.pop(context);
    });
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value, this.highlighted = false});
  final String label;
  final num value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(children: [
      Text(label, style: const TextStyle(color: Colors.white70)),
      Text(_money(value), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
        color: highlighted ? AppColors.accent : Colors.white)),
    ]),
  );
}

class _BuffetPicker extends ConsumerStatefulWidget {
  const _BuffetPicker({required this.device});
  final DeviceRow device;

  @override
  ConsumerState<_BuffetPicker> createState() => _BuffetPickerState();
}

class _BuffetPickerState extends ConsumerState<_BuffetPicker> {
  final _selected = <String, int>{};
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuItemsStreamProvider).valueOrNull ?? <MenuItemRow>[];
    final categories = ref.watch(buffetCategoriesStreamProvider).valueOrNull ?? <BuffetCategoryRow>[];
    final stock = {for (final row in ref.watch(inventoryStreamProvider).valueOrNull ?? <InventoryItemRow>[]) row.itemName: row.quantity};
    final existing = Map<String, int>.from(jsonDecode(widget.device.ordersJson) as Map);
    final filtered = menu.where((row) => (_category == null || row.categoryId == _category) &&
        row.itemName.toLowerCase().contains(_query)).toList();
    final count = _selected.values.fold<int>(0, (sum, value) => sum + value);
    final total = menu.fold<int>(0, (sum, item) => sum + item.price * (_selected[item.itemName] ?? 0));
    return AlertDialog(
      title: _Heading(icon: Icons.local_cafe_outlined, title: 'اختار أصناف البوفيه', subtitle: widget.device.displayName),
      content: SizedBox(
        width: 620,
        height: 395,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(autofocus: true, decoration: const InputDecoration(
              labelText: 'ابحث عن صنف', prefixIcon: Icon(Icons.search),
            ), onChanged: (value) => setState(() => _query = value.trim().toLowerCase())),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip(null, 'الكل'),
                for (final row in categories) _chip(row.id, '${row.emoji} ${row.name}'),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(child: filtered.isEmpty
              ? const Center(child: Text('مفيش أصناف مطابقة. تقدر تضيف أصناف من الإعدادات.'))
              : ListView.builder(itemCount: filtered.length, itemBuilder: (context, index) {
                final row = filtered[index];
                final qty = _selected[row.itemName] ?? 0;
                final inStock = stock[row.itemName];
                final already = existing[row.itemName] ?? 0;
                return Card(
                  child: ListTile(
                    title: Text(row.itemName),
                    subtitle: Text('${_money(row.price)}${inStock == null ? '' : ' • متاح: ${(inStock - already).clamp(0, inStock)}'}'),
                    trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                      IconButton(tooltip: 'تقليل الكمية', onPressed: qty == 0 ? null : () => setState(() {
                        if (qty == 1) {
                          _selected.remove(row.itemName);
                        } else {
                          _selected[row.itemName] = qty - 1;
                        }
                      }), icon: const Icon(Icons.remove_circle_outline)),
                      SizedBox(width: 28, child: Text('$qty', textAlign: TextAlign.center)),
                      IconButton(tooltip: 'زيادة الكمية', onPressed: inStock != null && qty + already >= inStock
                          ? null : () => setState(() => _selected[row.itemName] = qty + 1),
                          icon: const Icon(Icons.add_circle_outline)),
                    ]),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton.icon(
          onPressed: count == 0 ? null : () => Navigator.pop(context, _selected),
          icon: const Icon(Icons.check),
          label: Text('إضافة $count • ${_money(total)}'),
        ),
      ],
    );
  }

  Widget _chip(String? category, String label) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 6),
    child: ChoiceChip(label: Text(label), selected: _category == category,
      onSelected: (_) => setState(() => _category = category)),
  );
}
