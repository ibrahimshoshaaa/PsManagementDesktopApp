import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/table_logic.dart';
import '../../providers/core_providers.dart';
import '../drink_tables/drink_tables_controller.dart';
import '../tables/tables_controller.dart';
import 'buffet_picker.dart';
import 'operation_dialog.dart';

String _money(num value) => '${value.toStringAsFixed(2)} ج';
Map<String, int> _orders(String raw) => Map<String, int>.from(jsonDecode(raw) as Map);

class StationsScreen extends ConsumerWidget {
  const StationsScreen({super.key, required this.drinks});
  final bool drinks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = drinks ? <GameTableRow>[] : ref.watch(gameTablesStreamProvider).valueOrNull ?? <GameTableRow>[];
    final bar = drinks ? ref.watch(drinkTablesStreamProvider).valueOrNull ?? <DrinkTableRow>[] : <DrinkTableRow>[];
    final rows = <({int id, String name, bool active})>[
      for (final row in game) (id: row.tableId, name: row.name, active: row.isActive),
      for (final row in bar) (id: row.tableId, name: row.name, active: _orders(row.ordersJson).isNotEmpty),
    ];
    final active = rows.where((row) => row.active).length;
    final color = drinks ? AppColors.orange : AppColors.accent;
    return CustomScrollView(slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        sliver: SliverToBoxAdapter(
          child: Card(
            child: ListTile(
              leading: Icon(drinks ? Icons.local_cafe_outlined : Icons.table_bar, color: color),
              title: Text(drinks ? 'تربيزات المشروبات' : 'صالة التربيزات'),
              subtitle: Text(drinks ? 'إدارة الطلبات وحساب المشروبات' : 'جلسات البلياردو والبينج وحساب الوقت أو اللعبة'),
              trailing: Text('$active مشغولة  •  ${rows.length - active} متاحة'),
            ),
          ),
        ),
      ),
      if (rows.isEmpty)
        const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('أضف تربيزات من الإعدادات عشان تبدأ')))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 330, mainAxisExtent: 202, crossAxisSpacing: 14, mainAxisSpacing: 14,
            ),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return _StationCard(key: ValueKey(row.id), id: row.id, drinks: drinks);
            },
          ),
        ),
    ]);
  }
}

class _StationCard extends ConsumerWidget {
  const _StationCard({super.key, required this.id, required this.drinks});
  final int id;
  final bool drinks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = _station(ref, id, drinks);
    if (row == null) return const SizedBox.shrink();
    if (row.game?.isActive ?? false) ref.watch(tickerProvider);
    final color = drinks ? AppColors.orange : AppColors.accent;
    final active = row.game?.isActive ?? row.orders.isNotEmpty;
    void open() => showDialog<void>(context: context, builder: (_) => _StationDialog(id: id, drinks: drinks));
    return Card(
      color: AppColors.card,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(drinks ? Icons.local_cafe_outlined : Icons.table_bar, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(row.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              Text(active ? (row.game?.countdownFinished == true ? 'انتهى الوقت' : row.game?.isPaused == true ? 'متوقفة' : 'مشغولة') : 'متاحة', style: TextStyle(color: active ? color : Colors.white70)),
            ]),
            const Spacer(),
            Text(row.game?.isActive == true ? row.game!.timerText() : active ? _money(row.buffet) : 'جاهزة',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            if (row.game?.isActive == true)
              Text('إجمالي حالي ${_money(row.buffet + row.game!.hourlyTimeCost)}', textAlign: TextAlign.center),
            const Spacer(),
            FilledButton.tonalIcon(onPressed: open,
              icon: Icon(active ? Icons.receipt_long_outlined : drinks ? Icons.add_shopping_cart : Icons.play_arrow),
              label: Text(active ? 'عرض الحساب' : drinks ? 'فتح الطلبات' : 'بدء جلسة')),
          ]),
        ),
      ),
    );
  }
}

typedef _Station = ({String name, GameTableRow? game, Map<String, int> orders, double buffet});

_Station? _station(WidgetRef ref, int id, bool drinks) {
  final game = drinks ? null : ref.watch(gameTablesStreamProvider).valueOrNull?.where((row) => row.tableId == id).firstOrNull;
  final bar = drinks ? ref.watch(drinkTablesStreamProvider).valueOrNull?.where((row) => row.tableId == id).firstOrNull : null;
  final name = game?.name ?? bar?.name;
  if (name == null) return null;
  final orders = _orders(game?.ordersJson ?? bar!.ordersJson);
  final prices = {for (final row in ref.watch(menuItemsStreamProvider).valueOrNull ?? <MenuItemRow>[]) row.itemName: row.price};
  final buffet = orders.entries.fold<double>(0, (sum, entry) => sum + (prices[entry.key] ?? 0) * entry.value);
  return (name: name, game: game, orders: orders, buffet: buffet);
}

class _StationDialog extends ConsumerStatefulWidget {
  const _StationDialog({required this.id, required this.drinks});
  final int id;
  final bool drinks;

  @override
  ConsumerState<_StationDialog> createState() => _StationDialogState();
}

class _StationDialogState extends ConsumerState<_StationDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error is StateError ? error.message.toString() : 'تعذر حفظ العملية.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = _station(ref, widget.id, widget.drinks);
    if (row == null) return AlertDialog(
      title: const Text('التربيزة غير متاحة'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع'))],
    );
    final game = row.game;
    final playing = game?.isActive ?? false;
    final canOrder = widget.drinks || playing;
    final admin = ref.watch(sessionProvider).role == UserRole.admin;
    final gameController = ref.read(tablesControllerProvider);
    if (playing) ref.watch(tickerProvider);
    final customers = ref.watch(localCustomersStreamProvider).valueOrNull ?? <LocalCustomer>[];
    final customer = customers.where((row) => row.id == game?.localCustomerId).firstOrNull;

    return AlertDialog(
      title: Text(row.name),
      content: SizedBox(width: 620, child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              Text(playing ? game!.timerText() : widget.drinks ? _money(row.buffet) : 'التربيزة متاحة',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.accent)),
              if (game != null) Text('${_money(game.rate)} / ساعة${game.gamePrice > 0 ? '  •  ${_money(game.gamePrice)} / لعبة' : ''}'),
              if (playing && game?.countdownTotalSeconds != null)
                Text(game!.countdownFinished ? 'انتهى الوقت المحدد' : 'الوقت المتبقي'),
              if (customer != null) Text('العميل: ${customer.name}'),
              if (playing) Text('لعب ${_money(game!.hourlyTimeCost)}  •  بوفيه ${_money(row.buffet)}'),
            ]),
          )),
          const SizedBox(height: 12),
          if (playing || (widget.drinks && row.orders.isNotEmpty))
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (playing) OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(() => game!.isPaused ? gameController.resume(widget.id) : gameController.pause(widget.id)),
                icon: Icon(game!.isPaused ? Icons.play_arrow : Icons.pause),
                label: Text(game!.isPaused ? 'استكمال' : 'إيقاف مؤقت'),
              ),
              if (playing) OutlinedButton.icon(
                onPressed: _busy ? null : _adjust,
                icon: const Icon(Icons.more_time), label: const Text('تعديل الوقت'),
              ),
              OutlinedButton.icon(onPressed: _busy ? null : () => _transfer(row),
                icon: const Icon(Icons.swap_horiz), label: const Text('نقل للتربيزة')),
            ]),
          if (canOrder) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(child: Text('طلبات البوفيه', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              FilledButton.tonalIcon(onPressed: _busy ? null : () => _pick(row),
                icon: const Icon(Icons.add_shopping_cart), label: const Text('إضافة طلب')),
            ]),
            if (row.orders.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Text('مفيش طلبات لسه')),
            for (final item in row.orders.entries)
              ListTile(contentPadding: EdgeInsets.zero, title: Text(item.key), subtitle: Text('الكمية: ${item.value}'),
                trailing: IconButton(tooltip: 'إزالة واحدة', icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _busy ? null : () => _run(() => _add({item.key: -1})))),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: AppColors.red))),
        ],
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
        if (playing && admin) TextButton(
          onPressed: _busy ? null : _cancel,
          child: const Text('إلغاء الجلسة', style: TextStyle(color: AppColors.red)),
        ),
        if (game != null && !playing) ...[
          if (game.gamePrice > 0) OutlinedButton(
            onPressed: _busy ? null : () => _start(game, customers, fixedPrice: true),
            child: const Text('تسجيل لعبة'),
          ),
          FilledButton.icon(onPressed: _busy ? null : () => _start(game, customers),
            icon: const Icon(Icons.play_arrow), label: const Text('بدء جلسة')),
        ] else FilledButton.icon(
          onPressed: _busy || (!playing && row.orders.isEmpty) ? null : () => _checkout(row),
          icon: const Icon(Icons.receipt_long), label: const Text('حساب التربيزة'),
        ),
      ],
    );
  }

  Future<void> _start(GameTableRow game, List<LocalCustomer> customers, {bool fixedPrice = false}) {
    var mode = 'open';
    var custom = '';
    int? customerId;
    return showOperationDialog(
      context, title: fixedPrice ? 'تسجيل لعبة • ${game.name}' : 'بدء جلسة • ${game.name}',
      action: fixedPrice ? 'تسجيل اللعبة' : 'بدء اللعب',
      fields: [
        Text(fixedPrice ? 'سعر اللعبة: ${_money(game.gamePrice)}' : 'سعر الساعة: ${_money(game.rate)}'),
        if (!fixedPrice) ...[
          DropdownButtonFormField<String>(
            value: mode, isExpanded: true,
            decoration: const InputDecoration(labelText: 'مدة الجلسة'),
            items: const [
              DropdownMenuItem(value: 'open', child: Text('وقت مفتوح')),
              DropdownMenuItem(value: '30', child: Text('٣٠ دقيقة')),
              DropdownMenuItem(value: '60', child: Text('ساعة')),
              DropdownMenuItem(value: '90', child: Text('ساعة ونص')),
              DropdownMenuItem(value: 'custom', child: Text('مدة أخرى')),
            ],
            onChanged: (value) { if (value != null) mode = value; },
          ),
          TextFormField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'عدد الدقائق عند اختيار «مدة أخرى»'),
            onChanged: (value) => custom = value.trim(),
            validator: (_) {
              if (mode != 'custom') return null;
              final value = int.tryParse(custom);
              return value == null || value < 1 || value > 1440 ? 'اكتب مدة من دقيقة إلى ١٤٤٠ دقيقة' : null;
            },
          ),
        ],
        if (customers.isNotEmpty) DropdownButtonFormField<int>(
          value: -1, isExpanded: true, decoration: const InputDecoration(labelText: 'العميل (اختياري)'),
          items: [
            const DropdownMenuItem(value: -1, child: Text('بدون عميل')),
            for (final customer in customers) DropdownMenuItem(value: customer.id, child: Text(customer.name)),
          ],
          onChanged: (value) => customerId = value == -1 ? null : value,
        ),
      ],
      save: () async {
        final controller = ref.read(tablesControllerProvider);
        if (fixedPrice) {
          final recorded = await controller.recordGame(game.tableId, customerId: customerId);
          if (!recorded) throw StateError('التربيزة غير متاحة.');
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل اللعبة في السجل')));
        } else {
          final minutes = mode == 'open' ? null : int.parse(mode == 'custom' ? custom : mode);
          await controller.start(game.tableId, minutes: minutes, customerId: customerId);
        }
      },
    );
  }

  Future<void> _adjust() {
    var minutes = 0;
    return showOperationDialog(context, title: 'إضافة أو خصم وقت', action: 'حفظ التعديل', fields: [
      TextFormField(autofocus: true, keyboardType: const TextInputType.numberWithOptions(signed: true),
        decoration: const InputDecoration(labelText: 'الدقائق (مثلاً 15 أو -15)'),
        onChanged: (value) => minutes = int.tryParse(value.trim()) ?? 0,
        validator: (_) => minutes == 0 || minutes.abs() > 1440 ? 'اكتب عدد دقائق صالح' : null),
    ], save: () => ref.read(tablesControllerProvider).adjustMinutes(widget.id, minutes));
  }

  Future<void> _pick(_Station row) async {
    final selected = await showBuffetPicker(context, target: row.name);
    if (!mounted || selected == null) return;
    await _run(() => _add(selected));
  }

  Future<void> _add(Map<String, int> items) => widget.drinks
      ? ref.read(drinkTablesControllerProvider).addOrders(widget.id, items)
      : ref.read(tablesControllerProvider).addOrders(widget.id, items);

  Future<void> _transfer(_Station station) async {
    final game = station.game;
    final choices = <(int, String)>[
      if (widget.drinks)
        for (final row in ref.read(drinkTablesStreamProvider).valueOrNull ?? <DrinkTableRow>[])
          if (row.tableId != widget.id && _orders(row.ordersJson).isEmpty) (row.tableId, row.name),
      if (game != null)
        for (final row in ref.read(gameTablesStreamProvider).valueOrNull ?? <GameTableRow>[])
          if (!row.isActive && row.rate == game.rate && row.gamePrice == game.gamePrice && _orders(row.ordersJson).isEmpty)
            (row.tableId, row.name),
    ];
    final target = await showDialog<int>(context: context, builder: (dialog) => SimpleDialog(
      title: const Text('اختار التربيزة الجديدة'),
      children: [
        if (choices.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('مفيش تربيزة متاحة بنفس نظام الحساب')),
        for (final (id, name) in choices)
          SimpleDialogOption(onPressed: () => Navigator.pop(dialog, id), child: Text(name)),
      ],
    ));
    if (!mounted || target == null) return;
    await _run(() async {
      final transferred = widget.drinks
          ? await ref.read(drinkTablesControllerProvider).transfer(widget.id, target)
          : await ref.read(tablesControllerProvider).transfer(widget.id, target);
      if (!transferred) throw StateError('التربيزة الجديدة مش متاحة.');
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _checkout(_Station row) async {
    final game = row.game;
    final type = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: Text('حساب ${row.name}'),
      content: Text(game == null ? 'إجمالي المشروبات: ${_money(row.buffet)}'
          : 'بالساعة: ${_money(game.hourlyTimeCost + row.buffet)}${game.gamePrice > 0 ? '\nباللعبة: ${_money(game.gamePrice + row.buffet)}' : ''}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('رجوع')),
        if (game != null && game.gamePrice > 0)
          OutlinedButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('باللعبة')),
        FilledButton(onPressed: () => Navigator.pop(dialog, false), child: Text(game == null ? 'حفظ الفاتورة' : 'بالساعة')),
      ],
    ));
    if (!mounted || type == null) return;
    await _run(() async {
      final total = widget.drinks
          ? await ref.read(drinkTablesControllerProvider).checkout(widget.id)
          : (await ref.read(tablesControllerProvider).stop(widget.id, byGame: type))?['total'] as num?;
      if (!mounted || total == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ الفاتورة: ${_money(total)}')));
      Navigator.pop(context);
    });
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('إلغاء الجلسة من غير حساب؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('رجوع')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('إلغاء الجلسة')),
      ],
    ));
    if (!mounted || confirmed != true) return;
    await _run(() async {
      await ref.read(tablesControllerProvider).cancel(widget.id);
      if (mounted) Navigator.pop(context);
    });
  }
}
