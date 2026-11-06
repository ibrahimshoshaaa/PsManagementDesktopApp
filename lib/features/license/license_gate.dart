import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';
import 'device_id.dart';
import 'license_store.dart';
import 'license_token.dart';

class LicenseGate extends ConsumerStatefulWidget {
  const LicenseGate({super.key, required this.builder});

  final Widget Function(VoidCallback manageLicense) builder;

  @override
  ConsumerState<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends ConsumerState<LicenseGate> with WidgetsBindingObserver {
  String? _deviceId;
  DateTime? _expires;
  String? _error;
  bool _loading = true;
  bool _checking = false;
  bool _renewing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _recheck());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheck();
  }

  Future<void> _initialize() async {
    try {
      final device = await readLicenseDeviceId();
      if (!mounted) return;
      setState(() => _deviceId = device);
      await _recheck();
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر قراءة معرّف جهاز ويندوز.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recheck() async {
    final deviceId = _deviceId;
    if (!mounted || deviceId == null || _checking) return;
    _checking = true;
    try {
      final expires = await LicenseStore(ref.read(databaseProvider)).check(deviceId);
      if (mounted) setState(() => _expires = expires);
    } catch (error) {
      if (!mounted) return;
      final wasActive = _expires != null;
      setState(() {
        _expires = null;
        _error = _describe(error);
      });
      if (wasActive) {
        ref.read(sessionProvider.notifier).logout();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } finally {
      _checking = false;
    }
  }

  Future<String?> _activate(String token) async {
    final deviceId = _deviceId;
    if (deviceId == null || _checking) return 'استنى لحظة وحاول تاني.';
    _checking = true;
    try {
      final expires = await LicenseStore(ref.read(databaseProvider)).check(
        deviceId,
        activationCode: token,
      );
      if (mounted) {
        setState(() {
          _expires = expires;
          _error = null;
        });
      }
      return null;
    } catch (error) {
      return _describe(error);
    } finally {
      _checking = false;
    }
  }

  String _describe(Object error) {
    if (error is! LicenseException) return 'تعذر قراءة أو حفظ الترخيص المحلي.';
    return switch (error.problem) {
      LicenseProblem.unconfigured => 'نسخة ويندوز دي محتاجة إعداد مفتاح الترخيص قبل توزيعها.',
      LicenseProblem.invalid => 'كود الترخيص غير صالح.',
      LicenseProblem.otherDevice => 'الكود صادر لجهاز مختلف.',
      LicenseProblem.expired => 'مدة الترخيص انتهت. اطلب كود تجديد.',
      LicenseProblem.clock => 'راجع تاريخ ووقت ويندوز وبعدين جرّب تاني.',
    };
  }

  Future<void> _manageLicense() async {
    if (_renewing || _deviceId == null) return;
    _renewing = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _LicenseForm(
                deviceId: _deviceId!,
                expires: _expires,
                activate: _activate,
                closeOnSuccess: true,
              ),
            ),
          ),
        ),
      );
    } finally {
      _renewing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_expires != null) return widget.builder(_manageLicense);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 500,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _deviceId == null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error ?? 'معرّف الجهاز غير متاح.'),
                          TextButton(
                            onPressed: () {
                              setState(() => _loading = true);
                              _initialize();
                            },
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      )
                    : _LicenseForm(deviceId: _deviceId!, activate: _activate, initialError: _error),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LicenseForm extends StatefulWidget {
  const _LicenseForm({
    required this.deviceId,
    required this.activate,
    this.expires,
    this.initialError,
    this.closeOnSuccess = false,
  });

  final String deviceId;
  final DateTime? expires;
  final String? initialError;
  final bool closeOnSuccess;
  final Future<String?> Function(String token) activate;

  @override
  State<_LicenseForm> createState() => _LicenseFormState();
}

class _LicenseFormState extends State<_LicenseForm> {
  final _code = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _code.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final error = await widget.activate(_code.text);
    if (!mounted) return;
    if (error == null && widget.closeOnSuccess) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final expires = widget.expires?.toLocal().toString().split('.').first;
    final error = _error ?? widget.initialError;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ترخيص PS Management', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Text(expires == null ? 'ابعت معرّف الجهاز للحصول على كود التفعيل.' : 'الترخيص الحالي ساري لحد $expires'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: SelectableText(widget.deviceId, textDirection: TextDirection.ltr)),
            IconButton(
              tooltip: 'نسخ معرّف الجهاز',
              onPressed: () => Clipboard.setData(ClipboardData(text: widget.deviceId)),
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          textDirection: TextDirection.ltr,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'كود التفعيل أو التجديد'),
          onSubmitted: (_) => _save(),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'جاري التحقق…' : 'تفعيل الترخيص'),
        ),
      ],
    );
  }
}
