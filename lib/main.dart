import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
