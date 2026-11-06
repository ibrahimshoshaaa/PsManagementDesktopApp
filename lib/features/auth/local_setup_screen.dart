import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/password_utils.dart';
import '../../data/local/database.dart';
import '../../providers/core_providers.dart';

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
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 460,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.sports_esports_outlined, size: 44),
                      const SizedBox(height: 16),
                      Text('إعداد المحل لأول مرة', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text('البيانات هتتحفظ على الكمبيوتر ونسخة ويندوز تشتغل من غير إنترنت.'),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _shop,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'اسم المحل'),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'اكتب اسم المحل'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'كلمة سر الأدمن'),
                        validator: (value) => value == null || value.trim().length < 8
                            ? 'اكتب كلمة سر من 8 أحرف على الأقل'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'أكد كلمة السر'),
                        validator: (value) => value != _password.text ? 'كلمتا السر مختلفتان' : null,
                        onFieldSubmitted: (_) => _save(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'جاري الحفظ…' : 'حفظ وفتح تسجيل الدخول'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
