import '../shared/screen_ui.dart';

import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';

final _auditLogsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.localAuditEvents)
    ..orderBy([(t) => OrderingTerm.desc(t.id)])
    ..limit(100);
  return query.watch().map((rows) => [
    for (final row in rows) Map<String, dynamic>.from(jsonDecode(row.entryJson) as Map),
  ]);
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
          ScreenIntro(
            icon: Icons.fact_check_outlined, title: 'سجل التدقيق',
            description: 'آخر ١٠٠ عملية، مع اسم المستخدم والتوقيت.',
            actions: [
              IconButton(
                tooltip: 'تحديث السجل', icon: const Icon(Icons.refresh),
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
                  ? const ScreenEmpty(icon: Icons.fact_check_outlined, title: 'مفيش أحداث مسجلة', hint: 'إجراءات المستخدمين هتظهر هنا بعد تسجيلها.')
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
