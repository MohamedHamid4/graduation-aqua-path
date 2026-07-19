import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/errors/failures.dart';
import '../../core/logging/app_logger.dart';
import '../../features/organization/domain/entities/operations_report.dart';

enum ExportFormat { csv, pdf, excel }

/// Turns an already-loaded [OperationsReport] into a shareable file and
/// hands it to the OS share sheet, in one of three formats.
///
/// Every format renders exactly the same aggregated fields
/// [OperationsReport.toCsv] does — active/total drivers, active/total
/// trucks, completed trips, total liters, and the per-area/per-driver
/// liter breakdowns. Nothing beyond that (no household-level or
/// per-person data — [OperationsReport] never carries any) is ever
/// included, so there is no PII surface to leak regardless of format.
class ReportExportService {
  static const _fontRegularAsset = 'assets/fonts/Cairo-Regular.ttf';
  static const _fontBoldAsset = 'assets/fonts/Cairo-Bold.ttf';

  Future<Either<Failure, Unit>> exportCsv(OperationsReport report) async {
    try {
      // UTF-8 BOM so Excel on Windows renders the Arabic area/driver
      // names correctly instead of mojibake — the file content itself
      // (report.toCsv()) is unchanged from the existing export.
      final bytes = Uint8List.fromList([
        0xEF, 0xBB, 0xBF,
        ...utf8.encode(report.toCsv()),
      ]);
      await _share(bytes, 'aquapath_report.csv', 'text/csv');
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error('CSV export failed',
          tag: 'ReportExport', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل تصدير الملف بصيغة CSV'));
    }
  }

  Future<Either<Failure, Unit>> exportPdf(OperationsReport report) async {
    try {
      final bytes = await _buildPdf(report);
      await _share(bytes, 'aquapath_report.pdf', 'application/pdf');
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error('PDF export failed',
          tag: 'ReportExport', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل تصدير الملف بصيغة PDF'));
    }
  }

  Future<Either<Failure, Unit>> exportExcel(OperationsReport report) async {
    try {
      final bytes = _buildExcel(report);
      await _share(
        bytes,
        'aquapath_report.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error('Excel export failed',
          tag: 'ReportExport', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل تصدير الملف بصيغة Excel'));
    }
  }

  /// The one save/share path every format goes through — an OS share
  /// sheet via `share_plus`, so CSV/PDF/Excel behave identically once
  /// the bytes are ready.
  ///
  /// `XFile.fromData` keeps the file in memory only — it is never written
  /// to a path on disk by this code (no `path_provider`, no downloads
  /// folder). The platform share-sheet implementation is responsible for
  /// whatever ephemeral hand-off it needs internally; nothing here leaves
  /// a visible file behind. `downloadFallbackEnabled: false` closes the
  /// one loophole where that could stop being true: on web, the plugin's
  /// default is to silently trigger a browser download if the native
  /// Web Share API is unavailable — explicitly disabled so a failed share
  /// surfaces as an error instead of turning into a device download.
  ///
  /// Any failure here (including the share sheet being unavailable on
  /// the current platform, which `share_plus` reports as an
  /// [UnimplementedError]) is caught by the try/catch in the calling
  /// `export*` method and turned into a [Failure] — never a crash.
  Future<void> _share(Uint8List bytes, String fileName, String mimeType) {
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
        // XFile.fromData's `name` is ignored by cross_file on every
        // platform except web — this is the documented way to still get
        // the right filename in the share sheet everywhere else.
        fileNameOverrides: [fileName],
        subject: fileName,
        downloadFallbackEnabled: false,
      ),
    );
  }

  Future<Uint8List> _buildPdf(OperationsReport report) async {
    final regularFont = pw.Font.ttf(await rootBundle.load(_fontRegularAsset));
    final boldFont = pw.Font.ttf(await rootBundle.load(_fontBoldAsset));
    final dateFormat = DateFormat('yyyy/MM/dd');

    final doc = pw.Document(title: 'AquaPath Operations Report');

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text('تقرير عمليات AquaPath',
              style: pw.TextStyle(font: boldFont, fontSize: 20)),
          pw.SizedBox(height: 4),
          pw.Text(
            '${dateFormat.format(report.periodStart)} — '
            '${dateFormat.format(report.periodEnd.subtract(const Duration(days: 1)))}',
            style: pw.TextStyle(
                font: regularFont, fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          pw.Text('الملخص', style: pw.TextStyle(font: boldFont, fontSize: 14)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            context: context,
            headerDirection: pw.TextDirection.rtl,
            tableDirection: pw.TextDirection.rtl,
            headers: const ['المقياس', 'القيمة'],
            data: [
              ['السائقون النشطون', '${report.activeDrivers}'],
              ['إجمالي السائقين', '${report.totalDrivers}'],
              ['الشاحنات النشطة', '${report.activeTrucks}'],
              ['إجمالي الشاحنات', '${report.totalTrucks}'],
              ['الرحلات المكتملة', '${report.completedTrips}'],
              [
                'إجمالي اللترات الموزّعة',
                report.totalLitersDelivered.toStringAsFixed(0),
              ],
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('حسب المنطقة',
              style: pw.TextStyle(font: boldFont, fontSize: 14)),
          pw.SizedBox(height: 6),
          if (report.deliveriesByArea.isEmpty)
            pw.Text('لا توجد بيانات لهذه الفترة',
                style: pw.TextStyle(font: regularFont, fontSize: 11))
          else
            pw.TableHelper.fromTextArray(
              context: context,
              headerDirection: pw.TextDirection.rtl,
              tableDirection: pw.TextDirection.rtl,
              headers: const ['المنطقة', 'عدد التسليمات', 'اللترات'],
              data: report.deliveriesByArea.entries
                  .map((e) => [
                        e.key,
                        '${e.value}',
                        (report.litersByArea[e.key] ?? 0).toStringAsFixed(0),
                      ])
                  .toList(),
            ),
          pw.SizedBox(height: 20),
          pw.Text('حسب السائق',
              style: pw.TextStyle(font: boldFont, fontSize: 14)),
          pw.SizedBox(height: 6),
          if (report.litersByDriver.isEmpty)
            pw.Text('لا توجد بيانات لهذه الفترة',
                style: pw.TextStyle(font: regularFont, fontSize: 11))
          else
            pw.TableHelper.fromTextArray(
              context: context,
              headerDirection: pw.TextDirection.rtl,
              tableDirection: pw.TextDirection.rtl,
              headers: const ['السائق', 'اللترات الموزّعة'],
              data: report.litersByDriver.entries
                  .map((e) => [
                        report.driverNames[e.key] ?? e.key,
                        e.value.toStringAsFixed(0),
                      ])
                  .toList(),
            ),
        ],
      ),
    );

    return doc.save();
  }

  Uint8List _buildExcel(OperationsReport report) {
    final workbook = xls.Excel.createExcel();
    final defaultSheetName = workbook.getDefaultSheet()!;
    workbook.rename(defaultSheetName, 'الملخص');

    final summary = workbook['الملخص'];
    summary.appendRow([xls.TextCellValue('المقياس'), xls.TextCellValue('القيمة')]);
    summary.appendRow(
        [xls.TextCellValue('السائقون النشطون'), xls.IntCellValue(report.activeDrivers)]);
    summary.appendRow(
        [xls.TextCellValue('إجمالي السائقين'), xls.IntCellValue(report.totalDrivers)]);
    summary.appendRow(
        [xls.TextCellValue('الشاحنات النشطة'), xls.IntCellValue(report.activeTrucks)]);
    summary.appendRow(
        [xls.TextCellValue('إجمالي الشاحنات'), xls.IntCellValue(report.totalTrucks)]);
    summary.appendRow(
        [xls.TextCellValue('الرحلات المكتملة'), xls.IntCellValue(report.completedTrips)]);
    summary.appendRow([
      xls.TextCellValue('إجمالي اللترات الموزّعة'),
      xls.DoubleCellValue(report.totalLitersDelivered),
    ]);

    final byArea = workbook['حسب المنطقة'];
    byArea.appendRow([
      xls.TextCellValue('المنطقة'),
      xls.TextCellValue('عدد التسليمات'),
      xls.TextCellValue('اللترات'),
    ]);
    for (final entry in report.deliveriesByArea.entries) {
      byArea.appendRow([
        xls.TextCellValue(entry.key),
        xls.IntCellValue(entry.value),
        xls.DoubleCellValue(report.litersByArea[entry.key] ?? 0),
      ]);
    }

    final byDriver = workbook['حسب السائق'];
    byDriver.appendRow(
        [xls.TextCellValue('السائق'), xls.TextCellValue('اللترات الموزّعة')]);
    for (final entry in report.litersByDriver.entries) {
      byDriver.appendRow([
        xls.TextCellValue(report.driverNames[entry.key] ?? entry.key),
        xls.DoubleCellValue(entry.value),
      ]);
    }

    final bytes = workbook.save();
    if (bytes == null) {
      throw StateError('Excel encoding returned null');
    }
    return Uint8List.fromList(bytes);
  }
}
