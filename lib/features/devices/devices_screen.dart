import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/device_logic.dart';
import '../../providers/core_providers.dart';
import '../shared/qr_code_dialog.dart';
import 'devices_controller.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(tickerProvider); // يحدّث العدادات كل ثانية
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
        return Padding(
          padding: const EdgeInsets.all(20),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.05,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: devices.length,
            itemBuilder: (context, i) => _DeviceCard(device: devices[i]),
          ),
        );
      },
    );
  }
}

class _DeviceCard extends ConsumerWidget {
  final DeviceRow device;
  const _DeviceCard({required this.device});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(devicesControllerProvider);
    final prices = {for (final p in ref.watch(pricesStreamProvider).valueOrNull ?? <PriceRow>[]) p.priceKey: p.amount};
    final menu = {
      for (final m in ref.watch(menuItemsStreamProvider).valueOrNull ?? <MenuItemRow>[]) m.itemName: m.price
    };
    final isActive = device.isActive;
    final timeCost = isActive ? device.calculateTimePrice(prices) : 0.0;

    Map<String, int> orders = {};
    try {
      orders = Map<String, int>.from(jsonDecode(device.ordersJson) as Map);
    } catch (_) {}
    final buffetCost = device.buffetPrice(orders, menu);
    final total = timeCost + buffetCost;

    final isPs5 = device.deviceType == 'ps5';
    final glowColor = device.isPaused ? AppColors.amber : AppColors.accent;
    final statusColor = isActive ? glowColor : Colors.white24;

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
          onTap: () => _showDeviceSheet(context, ref),
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
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _showQr(context, ref),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.qr_code_2, size: 18, color: Colors.white38),
                      ),
                    ),
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
                      : Text(device.status, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                ),
                const Spacer(),
                if (!isActive)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => controller.start(device.deviceId, mode: 'normal'),
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
                          onPressed: () => _showDeviceSheet(context, ref),
                          icon: const Icon(Icons.fastfood, color: AppColors.orange),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: IconButton.filledTonal(
                          style: IconButton.styleFrom(backgroundColor: AppColors.redDark.withOpacity(0.3)),
                          onPressed: () => _confirmStop(context, ref),
                          icon: const Icon(Icons.stop, color: AppColors.red),
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

  void _showQr(BuildContext context, WidgetRef ref) {
    final shopId = ref.read(appConfigProvider).valueOrNull?.shopId;
    if (shopId == null) return;
    final isPs5 = device.deviceType == 'ps5';
    showQrCodeDialog(
      context,
      name: device.displayName,
      url: QrLinkBuilder.device(shopId, device.deviceId),
      color: isPs5 ? Colors.purple : AppColors.accent,
      typeLabel: isPs5 ? 'PS5' : 'PS4',
      icon: Icons.sports_esports,
      subtitle: 'سيتمكن العميل من رؤية الوقت والحساب\nوإرسال طلبات المشروبات مباشرة',
    );
  }

  void _confirmStop(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء الجلسة؟'),
        content: Text('هيتم حساب فاتورة ${device.displayName} وتسجيلها في السجل.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إنهاء')),
        ],
      ),
    );
    if (confirmed == true) {
      final session = ref.read(sessionProvider);
      final result = await ref
          .read(devicesControllerProvider)
          .stop(device.deviceId, closedBy: session.cashierName ?? 'admin');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('الإجمالي: ${(result['total'] as double).toStringAsFixed(1)} ج')),
        );
      }
    }
  }

  void _showDeviceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _DeviceDetailSheet(device: device),
    );
  }
}

/// شيت تفاصيل — أوردرات، مؤقت تنبيه، عد تنازلي، وإلغاء من غير حساب.
class _DeviceDetailSheet extends ConsumerStatefulWidget {
  final DeviceRow device;
  const _DeviceDetailSheet({required this.device});

  @override
  ConsumerState<_DeviceDetailSheet> createState() => _DeviceDetailSheetState();
}

class _DeviceDetailSheetState extends ConsumerState<_DeviceDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final menu = ref.watch(menuItemsStreamProvider).valueOrNull ?? [];
    final controller = ref.read(devicesControllerProvider);
    final timerController = TextEditingController(text: device.timerAlertMinutes?.toString() ?? '');
    final countdownController = TextEditingController(
      text: device.isCountdown && device.countdownTotalSeconds != null ? (device.countdownTotalSeconds! ~/ 60).toString() : '',
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(device.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          if (device.isActive) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: timerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'تنبيه بعد (دقيقة)'),
                    onSubmitted: (v) => controller.setTimerAlert(device.deviceId, int.tryParse(v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: countdownController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'عد تنازلي (دقيقة)'),
                    onSubmitted: (v) => controller.setCountdown(device.deviceId, int.tryParse(v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          const Text('أضف من البوفيه', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: menu
                .map((m) => ActionChip(
                      label: Text('${m.itemName} (${m.price} ج)'),
                      onPressed: () => controller.addOrder(device.deviceId, m.itemName, 1),
                    ))
                .toList(),
          ),
          if (device.isActive) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('إلغاء الجلسة من غير حساب؟'),
                      content: const Text('مش هيتسجل أي فاتورة، والجهاز هيرجع متاح على طول.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إلغاء الجلسة')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await controller.cancel(device.deviceId);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('إلغاء الجلسة من غير حساب'),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
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
