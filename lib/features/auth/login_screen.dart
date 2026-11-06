import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/screen_ui.dart';
import '../../core/utils/password_utils.dart';
import '../../providers/core_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onLoggedIn;
  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _adminMode = true;
  String? _selectedCashier;
  final _passwordController = TextEditingController();
  String? _error;
  bool _showPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final config = ref.read(appConfigProvider).valueOrNull;
    if (config == null) return;
    final entered = hashPassword(_passwordController.text);

    if (_adminMode) {
      if (entered == config.adminPasswordHash) {
        ref.read(sessionProvider.notifier).loginAsAdmin();
        widget.onLoggedIn();
      } else {
        setState(() => _error = 'كلمة السر غلط');
      }
      return;
    }

    if (_selectedCashier == null) {
      setState(() => _error = 'اختار الكاشير الأول');
      return;
    }
    final cashiers = ref.read(cashiersStreamProvider).valueOrNull ?? [];
    final cashier = cashiers.where((c) => c.name == _selectedCashier).firstOrNull;
    if (cashier != null && entered == cashier.passwordHash) {
      ref.read(sessionProvider.notifier).loginAsCashier(cashier.name);
      widget.onLoggedIn();
    } else {
      setState(() => _error = 'كلمة السر غلط');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cashiers = ref.watch(cashiersStreamProvider).valueOrNull ?? [];
    final shopName = ref.watch(appConfigProvider).valueOrNull?.shopName ?? '';

    final availableCashier = cashiers.any((row) => row.name == _selectedCashier) ? _selectedCashier : null;
    return AccessFrame(
      icon: Icons.sports_esports_outlined,
      title: shopName.isEmpty ? 'PS Management' : shopName,
      caption: 'سجّل دخولك عشان تفتح مساحة شغلك',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('مدير المحل'), icon: Icon(Icons.admin_panel_settings_outlined)),
            ButtonSegment(value: false, label: Text('كاشير'), icon: Icon(Icons.point_of_sale)),
          ],
          selected: {_adminMode},
          onSelectionChanged: (values) => setState(() {
            _adminMode = values.single;
            _error = null;
            _showPassword = false;
            _passwordController.clear();
          }),
        ),
        const SizedBox(height: 18),
        if (!_adminMode) ...[
          if (cashiers.isEmpty)
            const Text('لسه مفيش حساب كاشير. ادخل كمدير وأضف حساب من الإعدادات.')
          else
            DropdownButtonFormField<String>(
              value: availableCashier,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'حساب الكاشير', prefixIcon: Icon(Icons.badge_outlined)),
              items: [for (final row in cashiers) DropdownMenuItem(value: row.name, child: Text(row.name))],
              onChanged: (value) => setState(() { _selectedCashier = value; _error = null; }),
            ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _passwordController,
          autofocus: _adminMode,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: 'كلمة السر', errorText: _error, prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _showPassword ? 'إخفاء كلمة السر' : 'إظهار كلمة السر',
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            ),
          ),
          onChanged: (_) { if (_error != null) setState(() => _error = null); },
          onSubmitted: (_) { if (_adminMode || cashiers.isNotEmpty) _login(); },
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _adminMode || cashiers.isNotEmpty ? _login : null,
          icon: const Icon(Icons.login), label: const Text('تسجيل الدخول'),
        ),
      ]),
    );
  }
}
