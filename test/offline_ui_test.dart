import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psapp_flutter/core/theme/app_theme.dart';
import 'package:psapp_flutter/features/shared/operation_dialog.dart';
import 'package:psapp_flutter/features/shared/screen_ui.dart';

void main() {
  testWidgets('toolbar actions remain accessible in a narrow Arabic window', (tester) async {
    await tester.binding.setSurfaceSize(const Size(640, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: ScreenIntro(
          icon: Icons.payments_outlined, title: 'المصروفات',
          description: 'إجمالي الشهر',
          actions: [
            OutlinedButton(onPressed: () {}, child: const Text('Excel')),
            FilledButton(onPressed: () {}, child: const Text('مصروف جديد')),
          ],
        )),
      ),
    ));
    expect(find.text('مصروف جديد').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form errors and failed saves keep the entered value', (tester) async {
    var value = '';
    var attempt = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: Builder(builder: (context) => FilledButton(
        onPressed: () => showOperationDialog(context,
          title: 'مصروف جديد',
          action: 'حفظ',
          fields: [
            TextFormField(
              onChanged: (text) => value = text,
              validator: (_) => value.isEmpty ? 'اكتب البيان' : null,
            ),
          ],
          save: () async { attempt++; throw StateError('تعذر تسجيل المصروف'); },
        ),
        child: const Text('فتح'),
      ))),
    ));
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('اكتب البيان'), findsOneWidget);
    expect(attempt, 0);
    await tester.enterText(find.byType(TextFormField), 'إيجار');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(attempt, 1);
    expect(find.text('تعذر تسجيل المصروف'), findsOneWidget);
    expect(find.text('إيجار'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
