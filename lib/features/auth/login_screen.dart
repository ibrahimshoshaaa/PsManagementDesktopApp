import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sports_esports, size: 48, color: AppColors.accent),
                  const SizedBox(height: 12),
                  Text(shopName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 20),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('أدمن'), icon: Icon(Icons.admin_panel_settings)),
                      ButtonSegment(value: false, label: Text('كاشير'), icon: Icon(Icons.point_of_sale)),
                    ],
                    selected: {_adminMode},
                    onSelectionChanged: (s) => setState(() {
                      _adminMode = s.first;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 20),
                  if (!_adminMode)
                    DropdownButtonFormField<String>(
                      value: _selectedCashier,
                      decoration: const InputDecoration(labelText: 'الكاشير'),
                      dropdownColor: AppColors.card2,
                      items: cashiers
                          .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCashier = v),
                    ),
                  if (!_adminMode) const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'كلمة السر', errorText: _error),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(onPressed: _login, child: const Text('دخول')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
