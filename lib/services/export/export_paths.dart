import 'dart:io';
import 'package:path/path.dart' as p;
import '../../data/local/connection.dart';

/// مجلد التقارير — جوه نفس مجلد التطبيق (زي قاعدة البيانات)، عشان يفضل
/// المشروع portable ومفيش اعتماد على مجلدات ويندوز الخاصة بالمستخدم.
Future<Directory> getReportsDir() async {
  final base = await getAppBaseDir();
  final dir = Directory(p.join(base.path, 'Reports'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// يفتح مجلد التقارير في مستكشف ويندوز.
Future<void> openReportsFolderInExplorer() async {
  final dir = await getReportsDir();
  if (Platform.isWindows) {
    await Process.run('explorer', [dir.path]);
  }
}

String timestampedFileName(String prefix, String extension) {
  final now = DateTime.now();
  final stamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  return '${prefix}_$stamp.$extension';
}
