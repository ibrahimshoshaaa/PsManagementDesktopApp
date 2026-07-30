import 'dart:io';
import 'package:excel/excel.dart';

import '../../data/local/database.dart';
import 'export_paths.dart';

class ExcelExportService {
  static Future<String> exportHistory(List<HistoryRecordRow> records) async {
    final excel = Excel.createExcel();
    final sheet = excel['السجل'];
    excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('الاسم'),
      TextCellValue('النوع'),
      TextCellValue('الإجمالي'),
      TextCellValue('الوقت'),
      TextCellValue('البوفيه'),
      TextCellValue('التاريخ'),
    ]);
    for (final r in records) {
      sheet.appendRow([
        TextCellValue(r.name),
        TextCellValue(r.deviceType ?? '-'),
        DoubleCellValue(r.total),
        DoubleCellValue(r.timeCost),
        DoubleCellValue(r.buffetCost),
        TextCellValue(r.date),
      ]);
    }

    return _save(excel, timestampedFileName('history', 'xlsx'));
  }

  static Future<String> exportExpenses(List<ExpenseRow> expenses) async {
    final excel = Excel.createExcel();
    final sheet = excel['المصروفات'];
    excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('البيان'),
      TextCellValue('الفئة'),
      TextCellValue('المبلغ'),
      TextCellValue('التاريخ'),
      TextCellValue('بواسطة'),
    ]);
    for (final e in expenses) {
      sheet.appendRow([
        TextCellValue(e.title),
        TextCellValue(e.category),
        DoubleCellValue(e.amount),
        TextCellValue(e.date),
        TextCellValue(e.addedBy),
      ]);
    }

    return _save(excel, timestampedFileName('expenses', 'xlsx'));
  }

  static Future<String> exportDebts(List<DebtRow> debts) async {
    final excel = Excel.createExcel();
    final sheet = excel['المديونيات'];
    excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('الاسم'),
      TextCellValue('المبلغ المتبقي'),
      TextCellValue('التاريخ'),
      TextCellValue('الحالة'),
      TextCellValue('ملاحظة'),
    ]);
    for (final d in debts) {
      sheet.appendRow([
        TextCellValue(d.name),
        DoubleCellValue(d.amount),
        TextCellValue(d.date),
        TextCellValue(d.paid ? 'مسدد' : 'مستحق'),
        TextCellValue(d.note ?? ''),
      ]);
    }

    return _save(excel, timestampedFileName('debts', 'xlsx'));
  }

  static Future<String> _save(Excel excel, String fileName) async {
    final dir = await getReportsDir();
    final bytes = excel.encode();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes!);
    return file.path;
  }
}
