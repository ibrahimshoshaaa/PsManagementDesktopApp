import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/audit_log_service.dart';
import '../../data/remote/firebase_service.dart';

final _auditLogsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final shopId = FirebaseService.currentShopId;
  if (shopId == null) return [];
  return fetchAuditLogs(shopId);
});

class AuditLogsScreen extends ConsumerWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(_auditLogsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('سجل التدقيق', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54),
                onPressed: () => ref.invalidate(_auditLogsProvider),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('حصل خطأ: $e', style: const TextStyle(color: Colors.white))),
              data: (logs) => logs.isEmpty
                  ? const Center(child: Text('مفيش أحداث مسجلة', style: TextStyle(color: Colors.white38)))
                  : ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final l = logs[i];
                        final isAdmin = l['role'] == 'admin';
                        return ListTile(
                          leading: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: Colors.white54),
                          title: Text(l['action_details']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            '${l['cashier_name'] ?? ''} · ${_formatTimestamp(l['timestamp'])}',
                            style: TextStyle(color: Colors.white.withOpacity(0.4)),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    final d = DateTime.tryParse(ts.toString());
    if (d == null) return ts.toString();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
