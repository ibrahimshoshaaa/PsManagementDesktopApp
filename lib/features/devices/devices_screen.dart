import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/device_logic.dart';
import '../../providers/core_providers.dart';
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
    final isActive = device.isActive;
    final cost = isActive ? device.calculateTimePrice(prices) : 0.0;

    final statusColor = isActive ? (device.isPaused ? AppColors.amber : AppColors.green) : Colors.white24;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDeviceSheet(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(device.deviceType == 'ps5' ? Icons.videogame_asset : Icons.sports_esports,
                      color: statusColor, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(device.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                ],
              ),
              const Spacer(),
              Text(
                isActive ? device.timerText() : '—',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                isActive ? '${cost.toStringAsFixed(1)} ج' : device.status,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
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
