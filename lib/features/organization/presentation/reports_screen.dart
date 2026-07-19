import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/aqua_app_bar.dart';
import '../../../shared/services/report_export_service.dart';
import '../domain/entities/operations_report.dart';
import 'providers/organization_providers.dart';

/// Driver, area, and delivery analytics for a selected period
/// (daily/weekly/monthly). Built on [periodReportProvider], which is
/// itself scoped correctly to the selected date range (see the fix note
/// in `OrganizationRepositoryImpl.buildReport` — this used to return the
/// same lifetime total regardless of period).
class OrgReportsScreen extends ConsumerWidget {
  const OrgReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedReportPeriodProvider);
    final reportAsync = ref.watch(periodReportProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AquaAppBar(
        title: 'التقارير والتحليلات',
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded,
                color: AppColors.textPrimary),
            onPressed: reportAsync.valueOrNull == null
                ? null
                : () => _showExportFormatSheet(context, reportAsync.valueOrNull!),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: _PeriodTabs(
              selected: period,
              onChanged: (p) =>
                  ref.read(selectedReportPeriodProvider.notifier).state = p,
            ),
          ),
          Expanded(
            child: reportAsync.when(
              data: (report) {
                if (report == null) {
                  return Center(
                    child: Text('تعذّر تحميل التقرير',
                        style: GoogleFonts.cairo(color: AppColors.danger)),
                  );
                }
                return _ReportBody(report: report);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('تعذّر تحميل التقرير',
                    style: GoogleFonts.cairo(color: AppColors.danger)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportFormatSheet(BuildContext context, OperationsReport report) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 8.h),
              child: Text(
                AppStrings.reportsExportTitle,
                style: GoogleFonts.cairo(
                    fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
            ),
            _ExportOptionTile(
              icon: Icons.description_outlined,
              label: AppStrings.reportsExportCsvLabel,
              subtitle: AppStrings.reportsExportCsvDesc,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _runExport(context, ExportFormat.csv, report);
              },
            ),
            _ExportOptionTile(
              icon: Icons.picture_as_pdf_outlined,
              label: AppStrings.reportsExportPdfLabel,
              subtitle: AppStrings.reportsExportPdfDesc,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _runExport(context, ExportFormat.pdf, report);
              },
            ),
            _ExportOptionTile(
              icon: Icons.grid_on_outlined,
              label: AppStrings.reportsExportExcelLabel,
              subtitle: AppStrings.reportsExportExcelDesc,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _runExport(context, ExportFormat.excel, report);
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  Future<void> _runExport(
    BuildContext context,
    ExportFormat format,
    OperationsReport report,
  ) async {
    final service = GetIt.I<ReportExportService>();
    final result = switch (format) {
      ExportFormat.csv => await service.exportCsv(report),
      ExportFormat.pdf => await service.exportPdf(report),
      ExportFormat.excel => await service.exportExcel(report),
    };
    if (!context.mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.danger,
        ),
      ),
      (_) {},
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportOptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Icon(icon, color: AppColors.primaryDark),
      ),
      title: Text(label,
          style:
              GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14.sp)),
      subtitle: Text(subtitle,
          style: GoogleFonts.cairo(fontSize: 11.sp, color: AppColors.textMuted)),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onChanged;

  const _PeriodTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = {
      ReportPeriod.daily: 'يومي',
      ReportPeriod.weekly: 'أسبوعي',
      ReportPeriod.monthly: 'شهري',
    };

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.entries.map((entry) {
          final isSelected = entry.key == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  entry.value,
                  style: GoogleFonts.cairo(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final OperationsReport report;

  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final sortedDrivers = report.litersByDriver.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedAreas = report.litersByArea.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
      children: [
        Text(
          '${dateFormat.format(report.periodStart)} — ${dateFormat.format(report.periodEnd.subtract(const Duration(days: 1)))}',
          style: GoogleFonts.cairo(fontSize: 12.sp, color: AppColors.textMuted),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'إجمالي اللترات الموزّعة',
                value: report.totalLitersDelivered.toStringAsFixed(0),
                icon: Icons.water_drop_outlined,
                color: AppColors.info,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _MetricTile(
                label: 'الرحلات المكتملة',
                value: '${report.completedTrips}',
                icon: Icons.route_outlined,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'السائقون النشطون',
                value: '${report.activeDrivers}/${report.totalDrivers}',
                icon: Icons.groups_outlined,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _MetricTile(
                label: 'الشاحنات النشطة',
                value: '${report.activeTrucks}/${report.totalTrucks}',
                icon: Icons.local_shipping_outlined,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),
        _SectionHeader(
            title: 'إحصائيات السائقين', icon: Icons.leaderboard_outlined),
        SizedBox(height: 8.h),
        if (sortedDrivers.isEmpty)
          _EmptyNote(text: 'لا توجد عمليات تسليم مسجّلة لهذه الفترة')
        else
          _RankedList(
            items: sortedDrivers
                .map((e) => (
                      label: report.driverNames[e.key] ?? e.key,
                      value: '${e.value.toStringAsFixed(0)} لتر',
                    ))
                .toList(),
          ),
        SizedBox(height: 24.h),
        _SectionHeader(title: 'إحصائيات المناطق', icon: Icons.map_outlined),
        SizedBox(height: 8.h),
        if (sortedAreas.isEmpty)
          _EmptyNote(text: 'لا توجد عمليات تسليم مسجّلة لهذه الفترة')
        else
          _RankedList(
            items: sortedAreas
                .map((e) => (
                      label: e.key,
                      value:
                          '${e.value.toStringAsFixed(0)} لتر · ${report.deliveriesByArea[e.key] ?? 0} تسليم',
                    ))
                .toList(),
          ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20.w),
          SizedBox(height: 6.h),
          Text(value,
              style: GoogleFonts.cairo(
                  fontSize: 18.sp, fontWeight: FontWeight.w800)),
          Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 10.sp, color: AppColors.textMuted),
              maxLines: 2),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16.w, color: AppColors.primaryDark),
        SizedBox(width: 6.w),
        Text(title,
            style: GoogleFonts.cairo(
                fontSize: 14.sp, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text,
          style:
              GoogleFonts.cairo(fontSize: 12.sp, color: AppColors.textMuted)),
    );
  }
}

class _RankedList extends StatelessWidget {
  final List<({String label, String value})> items;
  const _RankedList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              border: i == items.length - 1
                  ? null
                  : Border(bottom: BorderSide(color: AppColors.bgSecondary)),
            ),
            child: Row(
              children: [
                Container(
                  width: 22.w,
                  height: 22.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i < 3
                        ? AppColors.primaryDark.withValues(alpha: 0.1)
                        : AppColors.bgSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: Text('${i + 1}',
                      style: GoogleFonts.cairo(
                          fontSize: 11.sp, fontWeight: FontWeight.w700)),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(item.label,
                      style: GoogleFonts.cairo(
                          fontSize: 13.sp, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(item.value,
                    style: GoogleFonts.cairo(
                        fontSize: 12.sp, color: AppColors.textMuted)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
