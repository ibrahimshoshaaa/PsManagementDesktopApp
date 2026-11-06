import 'package:flutter/material.dart';

double? parseMoney(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var normalized = input.trim().replaceAll('٫', '.').replaceAll(',', '.');
  for (var digit = 0; digit < 10; digit++) {
    normalized = normalized.replaceAll(arabic[digit], '$digit').replaceAll(persian[digit], '$digit');
  }
  final amount = double.tryParse(normalized);
  return amount != null && amount.isFinite && amount > 0 ? amount : null;
}

Future<void> showOperationDialog(
  BuildContext context, {
  required String title,
  required String action,
  required List<Widget> fields,
  required Future<void> Function() save,
}) => showDialog<void>(
  context: context,
  builder: (_) => _OperationDialog(title: title, action: action, fields: fields, save: save),
);

class _OperationDialog extends StatefulWidget {
  const _OperationDialog({required this.title, required this.action, required this.fields, required this.save});
  final String title, action;
  final List<Widget> fields;
  final Future<void> Function() save;

  @override
  State<_OperationDialog> createState() => _OperationDialogState();
}

class _OperationDialogState extends State<_OperationDialog> {
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await widget.save();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() {
        _error = error is StateError ? error.message.toString() : 'تعذر حفظ العملية. حاول تاني.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(width: 500, child: SingleChildScrollView(
      child: Form(key: _form, child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in widget.fields)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: field),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      )),
    )),
    actions: [
      TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('رجوع')),
      FilledButton.icon(onPressed: _saving ? null : _submit,
        icon: const Icon(Icons.check), label: Text(_saving ? 'جاري الحفظ…' : widget.action)),
    ],
  );
}
