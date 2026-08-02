import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// النسخة القديمة (Flet/Python) كانت بتخزن كل ملفات البيانات (ps_data_v3.json,
/// license.lic, shifts_archive.json...) جنب ملف الـ .exe نفسه (BASE_DIR):
///   - لو `sys.frozen` (نسخة exe مبنية) → جنب الـ exe
///   - غير كده (تشغيل مباشر من الكود) → جنب ملف بايثون
///
/// بنعمل نفس المنطق هنا عشان أي أداة/سكريبت خارجي بيقرا نفس المجلد يفضل شغال،
/// ولو حابب تنقل التخزين لمجلد AppData بدل جنب الـ exe (أنضف وأكثر أمانًا مع
/// صلاحيات ويندوز)، بدّل الدالة دي بـ path_provider's getApplicationSupportDirectory().
Future<Directory> getAppBaseDir() async {
  if (kReleaseMode) {
    return File(Platform.resolvedExecutable).parent;
  }
  // في وضع التطوير (flutter run) بيكون resolvedExecutable هو الـ Flutter
  // engine نفسه مش مفيد كمكان تخزين، فبنستخدم مجلد المشروع الحالي.
  return Directory.current;
}

/// يفتح اتصال SQLite في ملف `ps_app.sqlite` داخل مجلد التطبيق.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dir = await getAppBaseDir();
    final file = File(p.join(dir.path, 'ps_app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
