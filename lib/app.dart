import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/core_providers.dart';
import 'data/remote/subscription_service.dart';
import 'features/auth/activation_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/app_shell.dart';

class PSApp extends StatelessWidget {
  const PSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // التطبيق عربي بالكامل — RTL دايمًا بغض النظر عن لغة نظام التشغيل.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const _BootGate(),
    );
  }
}

enum _BootPhase { loading, needsActivation, needsLogin, ready }

class _BootGate extends ConsumerStatefulWidget {
  const _BootGate();
  @override
  ConsumerState<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends ConsumerState<_BootGate> {
  _BootPhase _phase = _BootPhase.loading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final subscriptionService = ref.read(subscriptionServiceProvider);
    final result = await subscriptionService.bootstrap();
    if (!mounted) return;

    switch (result.state) {
      case SubscriptionState.active:
        final config = await ref.read(databaseProvider).readConfigOnce();
        if (config.shopId != null) {
          await ref.read(syncServiceProvider).start(config.shopId!);
        }
        setState(() => _phase = _BootPhase.needsLogin);
        break;
      case SubscriptionState.needsActivation:
      case SubscriptionState.expired:
      case SubscriptionState.unknown:
        setState(() {
          _phase = _BootPhase.needsActivation;
          _errorMessage = result.errorMessage;
        });
        break;
    }
  }

  Future<void> _onActivated() async {
    setState(() => _phase = _BootPhase.loading);
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _BootPhase.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _BootPhase.needsActivation:
        return ActivationScreen(initialError: _errorMessage, onActivated: _onActivated);
      case _BootPhase.needsLogin:
        return LoginScreen(onLoggedIn: () => setState(() => _phase = _BootPhase.ready));
      case _BootPhase.ready:
        return const AppShell();
    }
  }
}
