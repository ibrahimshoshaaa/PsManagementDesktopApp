import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/device_logic.dart';
import '../../providers/core_providers.dart';
import 'devices_controller.dart';
import 'device_session_dialog.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

enum _DeviceFilter { all, available, running, paused }

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  _DeviceFilter _filter = _DeviceFilter.all;

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesStreamProvider);

    return devicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('حصل خطأ: $e', style: const TextStyle(color: Colors.white))),
      data: (devices) {
        if (devices.isEmpty) {
          return const Center(
            child: Text('مفيش أجهزة مضافة — أضيفها من الإعدادات', style: TextStyle(color: Colors.white38)),
          );
        }
        final available = devices.where((device) => !device.isActive).length;
        final running = devices.where((device) => device.isRunning).length;
        final paused = devices.length - available - running;
        final filtered = devices.where((device) => switch (_filter) {
          _DeviceFilter.all => true,
          _DeviceFilter.available => !device.isActive,
          _DeviceFilter.running => device.isRunning,
          _DeviceFilter.paused => device.isActive && device.isPaused,
        }).toList();
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF183D47), Color(0xFF172239)],
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accent.withOpacity(.22)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.sports_esports_outlined, color: AppColors.accent),
                        SizedBox(width: 10),
                        Expanded(child: Text('حالة صالة اللعب', style: TextStyle(
                          fontSize: 25, fontWeight: FontWeight.w700,
                        ))),
                      ]),
                      const SizedBox(height: 8),
                      const Text('اختار حالة لفلترة الأجهزة، أو افتح جهاز لإدارة الجلسة.'),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _filterChip(_DeviceFilter.all, 'كل الأجهزة', devices.length, Icons.grid_view),
                          _filterChip(_DeviceFilter.available, 'متاح', available, Icons.check_circle_outline),
                          _filterChip(_DeviceFilter.running, 'شغّال', running, Icons.play_circle_outline),
                          _filterChip(_DeviceFilter.paused, 'متوقف مؤقتًا', paused, Icons.pause_circle_outline),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('مفيش أجهزة بالحالة دي حاليًا')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 244,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _DeviceCard(
                    key: ValueKey(filtered[index].deviceId),
                    device: filtered[index],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _filterChip(_DeviceFilter filter, String label, int count, IconData icon) {
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text('$label  $count'),
      selected: _filter == filter,
      onSelected: (_) => setState(() => _filter = filter),
    );
  }
}

class _DeviceCard extends ConsumerWidget {
  final DeviceRow device;
  const _DeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(devicesControllerProvider);
    final prices = {for (final p in ref.watch(pricesStreamProvider).valueOrNull ?? <PriceRow>[]) p.priceKey: p.amount};
    final menu = {
      for (final m in ref.watch(menuItemsStreamProvider).valueOrNull ?? <MenuItemRow>[]) m.itemName: m.price
    };
    final isActive = device.isActive;
    if (isActive) ref.watch(tickerProvider);
    final timeCost = isActive ? device.calculateTimePrice(prices) : 0.0;

    Map<String, int> orders = {};
    try {
      orders = Map<String, int>.from(jsonDecode(device.ordersJson) as Map);
    } catch (_) {}
    final buffetCost = device.buffetPrice(orders, menu);
    final total = timeCost + buffetCost;

    final isPs5 = device.deviceType == 'ps5';
    final glowColor = device.countdownFinished ? AppColors.red : device.isPaused ? AppColors.amber : AppColors.accent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? glowColor : Colors.white12, width: isActive ? 1.5 : 1),
        boxShadow: isActive
            ? [BoxShadow(color: glowColor.withOpacity(0.25), blurRadius: 14, spreadRadius: 1)]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => openDeviceSession(context, device),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(device.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isActive) ...[
                      _Badge(
                        label: device.mode == 'multi' ? '👥 مالتي' : '👤 عادي',
                        color: device.mode == 'multi' ? AppColors.orange : AppColors.green,
                      ),
                      const SizedBox(width: 4),
                    ],
                    _Badge(label: isPs5 ? 'PS5' : 'PS4', color: isPs5 ? Colors.purple : AppColors.accent),
                  ],
                ),
                const Spacer(),
                Center(
                  child: _PulsingTimer(
                    text: isActive ? device.timerText() : '—',
                    active: isActive && !device.isPaused,
                    color: device.isPaused ? AppColors.amber : Colors.white,
                    glowColor: glowColor,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: isActive
                      ? Column(
                          children: [
                            Text('لعب: ${timeCost.toStringAsFixed(1)} | بوفيه: ${buffetCost.toStringAsFixed(1)}',
                                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
                            const SizedBox(height: 2),
                            Text('${total.toStringAsFixed(1)} ج',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.green)),
                          ],
                        )
                      : Text('جاهز للتشغيل', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                ),
                if (device.countdownFinished)
                  const Center(child: Text('انتهى الوقت المحدد', style: TextStyle(color: AppColors.red))),
                const Spacer(),
                if (!isActive)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => openDeviceSession(context, device),
                      child: const Text('تشغيل'),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: IconButton.filledTonal(
                          onPressed: () =>
                              device.isPaused ? controller.resume(device.deviceId) : controller.pause(device.deviceId),
                          icon: Icon(device.isPaused ? Icons.play_arrow : Icons.pause),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: IconButton.filledTonal(
                          style: IconButton.styleFrom(backgroundColor: AppColors.orange.withOpacity(0.2)),
                          onPressed: () => openDeviceSession(context, device, buffet: true),
                          icon: const Icon(Icons.fastfood, color: AppColors.orange),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: IconButton.filledTonal(
                          style: IconButton.styleFrom(backgroundColor: AppColors.redDark.withOpacity(0.3)),
                          onPressed: () => openDeviceSession(context, device),
                          icon: const Icon(Icons.receipt_long, color: AppColors.red),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.8), width: 1.2),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

/// عداد بينبض (زي نسخة الموبايل) — بيدّي إحساس إن الجلسة "شغالة فعلًا".
class _PulsingTimer extends StatefulWidget {
  final String text;
  final bool active;
  final Color color;
  final Color glowColor;
  const _PulsingTimer({required this.text, required this.active, required this.color, required this.glowColor});

  @override
  State<_PulsingTimer> createState() => _PulsingTimerState();
}

class _PulsingTimerState extends State<_PulsingTimer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  late final Animation<double> _anim =
      Tween(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, child) => Transform.scale(scale: widget.active ? _anim.value : 1.0, child: child),
      child: Text(
        widget.text,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: widget.color,
          shadows: widget.active ? [Shadow(color: widget.glowColor.withOpacity(0.5), blurRadius: 8)] : [],
        ),
      ),
    );
  }
}
