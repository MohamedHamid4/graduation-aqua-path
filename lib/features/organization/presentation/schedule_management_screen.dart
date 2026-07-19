import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/aqua_app_bar.dart';
import '../../driver/domain/entities/driver_profile.dart';
import '../../driver/domain/entities/driver_route.dart';
import '../domain/entities/service_area.dart';
import '../domain/repositories/organization_repository.dart';
import 'providers/organization_providers.dart';

/// Work-schedule (driver route) management. `OrganizationRepository`
/// already had `createRoute`/`watchAllRoutes`/`deleteRoute` — this screen
/// is what was missing to actually reach them; before this, an
/// organization operator had no way to create a driver's daily
/// assignment through the app at all (drivers only ever *read*
/// pre-existing routes via `driver_routes` — nothing ever wrote one).
class OrgScheduleManagementScreen extends ConsumerWidget {
  const OrgScheduleManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(allRoutesProvider);
    final driversAsync = ref.watch(allDriversProvider);
    final areasAsync = ref.watch(allAreasProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: const AquaAppBar(title: 'إدارة الجداول'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (driversAsync.valueOrNull?.isEmpty ?? true)
            ? null
            : () => _showCreateSheet(
                  context,
                  driversAsync.valueOrNull ?? [],
                  areasAsync.valueOrNull ?? [],
                ),
        backgroundColor: AppColors.primaryDark,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('رحلة جديدة',
            style: GoogleFonts.cairo(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: routesAsync.when(
        data: (routes) {
          if (routes.isEmpty) {
            return Center(
              child: Text('لا توجد جداول عمل بعد',
                  style: GoogleFonts.cairo(color: AppColors.textMuted)),
            );
          }
          final driverNames = {
            for (final d in driversAsync.valueOrNull ?? <DriverProfile>[])
              d.uid: d.fullName,
          };
          final sorted = [...routes]
            ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 90.h),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (_, i) => _RouteCard(
              route: sorted[i],
              driverName:
                  driverNames[sorted[i].driverUid] ?? sorted[i].driverUid,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('تعذّر تحميل الجداول',
              style: GoogleFonts.cairo(color: AppColors.danger)),
        ),
      ),
    );
  }

  void _showCreateSheet(
    BuildContext context,
    List<DriverProfile> drivers,
    List<ServiceArea> areas,
  ) {
    DriverProfile? selectedDriver = drivers.first;
    ServiceArea? selectedArea = areas.isNotEmpty ? areas.first : null;
    final areaNameCtrl = TextEditingController(text: selectedArea?.name ?? '');
    final litersCtrl = TextEditingController(text: '8000');
    final timeSlotCtrl = TextEditingController(text: 'صباحًا');
    DateTime scheduledDate = DateTime.now().add(const Duration(days: 1));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 20.h,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20.h,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('جدولة رحلة جديدة',
                        style: GoogleFonts.cairo(
                            fontSize: 16.sp, fontWeight: FontWeight.w700)),
                    SizedBox(height: 16.h),
                    DropdownButtonFormField<DriverProfile>(
                      value: selectedDriver,
                      decoration: const InputDecoration(
                        labelText: 'السائق',
                        border: OutlineInputBorder(),
                      ),
                      items: drivers
                          .map((d) => DropdownMenuItem(
                              value: d, child: Text(d.fullName)))
                          .toList(),
                      onChanged: (v) => setSheetState(() => selectedDriver = v),
                    ),
                    SizedBox(height: 14.h),
                    if (areas.isNotEmpty)
                      DropdownButtonFormField<ServiceArea>(
                        value: selectedArea,
                        decoration: const InputDecoration(
                          labelText: 'المنطقة',
                          border: OutlineInputBorder(),
                        ),
                        items: areas
                            .map((a) =>
                                DropdownMenuItem(value: a, child: Text(a.name)))
                            .toList(),
                        onChanged: (v) => setSheetState(() {
                          selectedArea = v;
                          areaNameCtrl.text = v?.name ?? '';
                        }),
                      )
                    else
                      TextField(
                        controller: areaNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم المنطقة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    SizedBox(height: 14.h),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: scheduledDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) {
                          setSheetState(() => scheduledDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'التاريخ',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                            DateFormat('yyyy/MM/dd').format(scheduledDate)),
                      ),
                    ),
                    SizedBox(height: 14.h),
                    TextField(
                      controller: timeSlotCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الفترة الزمنية (مثال: صباحًا)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 14.h),
                    TextField(
                      controller: litersCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الكمية المتوقعة (لتر)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: () async {
                          final driver = selectedDriver;
                          if (driver == null) return;
                          final area = selectedArea;
                          final areaName = areaNameCtrl.text.trim();
                          if (areaName.isEmpty) return;

                          final route = DriverRoute(
                            id: '',
                            driverUid: driver.uid,
                            areaName: areaName,
                            startLat: area?.centerLat ?? 31.5018,
                            startLng: area?.centerLng ?? 34.4668,
                            endLat: area?.centerLat ?? 31.5018,
                            endLng: area?.centerLng ?? 34.4668,
                            scheduledTime: scheduledDate,
                            timeSlot: timeSlotCtrl.text.trim(),
                            expectedLiters:
                                double.tryParse(litersCtrl.text.trim()) ?? 8000,
                          );

                          final result = await GetIt.I<OrganizationRepository>()
                              .createRoute(route);
                          if (sheetContext.mounted)
                            Navigator.of(sheetContext).pop();
                          if (context.mounted) {
                            result.fold(
                              (failure) =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(failure.message),
                                  backgroundColor: AppColors.danger,
                                ),
                              ),
                              (_) => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('تم إنشاء الجدول')),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('حفظ',
                            style:
                                GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RouteCard extends StatelessWidget {
  final DriverRoute route;
  final String driverName;

  const _RouteCard({required this.route, required this.driverName});

  Color get _statusColor => switch (route.status) {
        'completed' => AppColors.success,
        'in_progress' => AppColors.accent,
        _ => AppColors.warning,
      };

  String get _statusLabel => switch (route.status) {
        'completed' => 'مكتملة',
        'in_progress' => 'قيد التنفيذ',
        _ => 'قيد الانتظار',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 8.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: _statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$driverName · ${route.areaName}',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w700, fontSize: 13.sp)),
                Text(
                  '${DateFormat('yyyy/MM/dd').format(route.scheduledTime)} · ${route.timeSlot} · ${route.expectedLiters.toStringAsFixed(0)} لتر',
                  style: GoogleFonts.cairo(
                      fontSize: 11.sp, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_statusLabel,
                style: GoogleFonts.cairo(fontSize: 10.sp, color: _statusColor)),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
            onPressed: () async {
              final result =
                  await GetIt.I<OrganizationRepository>().deleteRoute(route.id);
              if (context.mounted) {
                result.fold(
                  (failure) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(failure.message),
                        backgroundColor: AppColors.danger),
                  ),
                  (_) {},
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
