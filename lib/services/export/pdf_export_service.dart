import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/local/database.dart';
import 'export_paths.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ⚠️ ملاحظة مهمة عن العربي في الـ PDF:
// بنستخدم خط Noto Sans Arabic من Google Fonts (عبر PdfGoogleFonts) — أول
// مرة يتولد فيها PDF محتاج إنترنت عشان يحمّل الخط، وبعدها بيتخزن محليًا
// (cache) وميحتجش نت تاني. لو عايز الموضوع offline بالكامل من أول تشغيل،
// نزّل ملف الخط .ttf حط، حطه في assets/fonts/NotoSansArabic-Regular.ttf،
// وسجّله في pubspec.yaml تحت flutter/fonts، واستبدل PdfGoogleFonts هنا بـ:
//   pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'))
//
// جودة تشكيل الحروف العربي (اتصال الحروف) بتعتمد على نسخة حزمة pdf — لو
// شكل الحروف طلع متقطع، جرّب ترقية الحزمة لأحدث إصدار أو استخدم خط عربي
// مختلف بيدعم OpenType shaping بشكل أفضل.
// ═══════════════════════════════════════════════════════════════════════════

class PdfExportService {
  static Future<pw.ThemeData> _arabicTheme() async {
    final regular = await PdfGoogleFonts.notoSansArabicRegular();
    final bold = await PdfGoogleFonts.notoSansArabicBold();
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }

  /// تقرير يومي — قائمة سجلات + إجماليات.
  static Future<String> exportDailyReport({
    required String shopName,
    required DateTime date,
    required List<HistoryRecordRow> records,
  }) async {
    final theme = await _arabicTheme();
    final doc = pw.Document(theme: theme);

    final total = records.fold<double>(0, (s, r) => s + r.total);
    final timeTotal = records.fold<double>(0, (s, r) => s + r.timeCost);
    final buffetTotal = records.fold<double>(0, (s, r) => s + r.buffetCost);
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(shopName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text('تقرير يوم $dateStr', style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _statBox('الإجمالي', '${total.toStringAsFixed(1)} ج'),
              _statBox('الوقت', '${timeTotal.toStringAsFixed(1)} ج'),
              _statBox('البوفيه', '${buffetTotal.toStringAsFixed(1)} ج'),
              _statBox('عدد الجلسات', '${records.length}'),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerDirection: pw.TextDirection.rtl,
            headers: ['الإجمالي', 'البوفيه', 'الوقت', 'النوع', 'الاسم'],
            data: records
                .map((r) => [
                      r.total.toStringAsFixed(1),
                      r.buffetCost.toStringAsFixed(1),
                      r.timeCost.toStringAsFixed(1),
                      r.deviceType ?? '-',
                      r.name,
                    ])
                .toList(),
            cellAlignment: pw.Alignment.centerRight,
            headerAlignment: pw.Alignment.centerRight,
          ),
        ],
      ),
    );

    return _save(doc, timestampedFileName('daily_report', 'pdf'));
  }

  static Future<String> exportShiftReport({
    required String shopName,
    required String cashierName,
    required DateTime startTime,
    required DateTime endTime,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final theme = await _arabicTheme();
    final doc = pw.Document(theme: theme);
    final total = transactions.fold<double>(0, (s, t) => s + ((t['total'] as num?)?.toDouble() ?? 0));

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(shopName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text('تقرير شيفت — $cashierName', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('من ${startTime.toString().substring(0, 16)} إلى ${endTime.toString().substring(0, 16)}',
                    style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          _statBox('إجمالي الإيراد', '${total.toStringAsFixed(1)} ج'),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerDirection: pw.TextDirection.rtl,
            headers: ['الإجمالي', 'البوفيه', 'الوقت', 'الاسم'],
            data: transactions
                .map((t) => [
                      (t['total'] as num?)?.toStringAsFixed(1) ?? '0',
                      (t['buffet_cost'] as num?)?.toStringAsFixed(1) ?? '0',
                      (t['time_cost'] as num?)?.toStringAsFixed(1) ?? '0',
                      t['name']?.toString() ?? '',
                    ])
                .toList(),
            cellAlignment: pw.Alignment.centerRight,
            headerAlignment: pw.Alignment.centerRight,
          ),
        ],
      ),
    );

    return _save(doc, timestampedFileName('shift_report', 'pdf'));
  }

  static pw.Widget _statBox(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        ],
      );

  static Future<String> _save(pw.Document doc, String fileName) async {
    final dir = await getReportsDir();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(await doc.save());
    return file.path;
  }
}
