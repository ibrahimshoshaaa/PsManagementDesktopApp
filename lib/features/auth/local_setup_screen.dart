import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/password_utils.dart';
import '../../data/local/database.dart';
import '../../providers/core_providers.dart';
import '../shared/screen_ui.dart';

class LocalSetupScreen extends ConsumerStatefulWidget {
  const LocalSetupScreen({super.key});

  @override
  ConsumerState<LocalSetupScreen> createState() => _LocalSetupScreenState();
}

class _LocalSetupScreenState extends ConsumerState<LocalSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _shop = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _shop.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final database = ref.read(databaseProvider);
      final hash = hashPassword(_password.text);
      await (database.update(database.appConfig)
            ..where((row) => row.id.equals(0)))
          .write(AppConfigCompanion(
        shopName: Value(_shop.text.trim()),
        adminPasswordHash: Value(hash),
        historyPasswordHash: Value(hash),
      ));
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر حفظ إعدادات المحل. حاول تاني.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccessFrame(
      icon: Icons.storefront_outlined,
      title: 'إعداد المحل لأول مرة',
      caption: 'اختار الاسم اللي هيظهر في الفواتير وكلمة سر مدير المحل.',
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _shop, autofocus: true, textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'اسم المحل', prefixIcon: Icon(Icons.storefront_outlined)),
              validator: (value) => value == null || value.trim().isEmpty ? 'اكتب اسم المحل' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password, obscureText: true, textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'كلمة سر الأدمن', helperText: '٨ حروف على الأقل',
                prefixIcon: Icon(Icons.lock_outline)),
              validator: (value) => value == null || value.trim().length < 8
                  ? 'اكتب كلمة سر من ٨ حروف على الأقل' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              obscureText: true,
              decoration: const InputDecoration(labelText: 'أكد كلمة السر', prefixIcon: Icon(Icons.lock_outline)),
              validator: (value) => value != _password.text ? 'كلمتا السر مختلفتان' : null,
              onFieldSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.check),
              label: Text(_saving ? 'جاري الحفظ…' : 'حفظ وفتح تسجيل الدخول')),
          ],
        ),
      ),
    );
  }
}
