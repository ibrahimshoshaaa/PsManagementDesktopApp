import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/core_providers.dart';
import 'features/auth/local_setup_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/license/license_gate.dart';

class PSApp extends StatelessWidget {
  const PSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS Management Offline',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // التطبيق عربي بالكامل — RTL دايمًا بغض النظر عن لغة نظام التشغيل.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: LicenseGate(builder: (manageLicense) => _BootGate(manageLicense: manageLicense)),
    );
  }
}

class _BootGate extends ConsumerWidget {
  const _BootGate({required this.manageLicense});

  final VoidCallback manageLicense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(sessionProvider);
    return config.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('تعذر فتح قاعدة البيانات المحلية.')),
      ),
      data: (settings) {
        if (settings.adminPasswordHash.isEmpty) return const LocalSetupScreen();
        if (session.role == UserRole.none) return LoginScreen(onLoggedIn: () {});
        return AppShell(onManageLicense: manageLicense);
      },
    );
  }
}
