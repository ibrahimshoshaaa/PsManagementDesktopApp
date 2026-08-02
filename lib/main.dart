import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // في وضع الـ release، فلاتر بيستبدل أي widget بيرمي خطأ وقت الرسم بمربع
  // رمادي فاضي من غير تفاصيل. بنجبره هنا يوري نص الخطأ الحقيقي عشان نقدر
  // نشخّص المشكلة من على أي جهاز، من غير ما نحتاج نسخة debug.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF3A0000),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          details.exceptionAsString(),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          textDirection: TextDirection.ltr,
        ),
      ),
    );
  };

  // إعدادات نافذة الويندوز — بتفتح full screen زي النسخة القديمة (Flet).
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    minimumSize: Size(1100, 700),
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: PSApp()));
}
