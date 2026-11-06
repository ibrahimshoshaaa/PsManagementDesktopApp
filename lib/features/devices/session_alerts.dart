import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/device_logic.dart';
import '../../domain/table_logic.dart';
import '../../providers/core_providers.dart';

class SessionAlerts extends ConsumerStatefulWidget {
  const SessionAlerts({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<SessionAlerts> createState() => _SessionAlertsState();
}

class _SessionAlertsState extends ConsumerState<SessionAlerts> {
  final _announced = <String>{};

  @override
  Widget build(BuildContext context) {
    ref.listen(tickerProvider, (_, tick) {
      if (!tick.hasValue) return;
      final devices = ref.read(devicesStreamProvider).valueOrNull;
      if (devices == null) return;
      final current = <String>{};
      final notices = <String>[];
      for (final device in devices) {
        if (!device.isActive) continue;
        final session = '${device.deviceId}:${device.startTime}';
        final alert = device.timerAlertMinutes;
        if (alert != null && alert > 0 && device.elapsedSeconds >= alert * 60) {
          final id = '$session:alert:$alert';
          current.add(id);
          if (_announced.add(id)) notices.add('${device.displayName} وصل لـ $alert دقيقة');
        }
        if (device.countdownFinished) {
          final id = '$session:end:${device.countdownTotalSeconds}';
          current.add(id);
          if (_announced.add(id)) notices.add('انتهى الوقت المحدد لـ ${device.displayName}');
        }
      }
      final tables = ref.read(gameTablesStreamProvider).valueOrNull ?? [];
      for (final table in tables) {
        if (!table.countdownFinished) continue;
        final id = 'table:${table.tableId}:${table.startTime}:${table.countdownTotalSeconds}';
        current.add(id);
        if (_announced.add(id)) notices.add('انتهى الوقت المحدد لـ ${table.name}');
      }
      _announced.retainAll(current);
      if (notices.isNotEmpty) {
        SystemSound.play(SystemSoundType.alert);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notices.join(' • '))));
      }
    });
    return widget.child;
  }
}
