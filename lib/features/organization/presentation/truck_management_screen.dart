import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/aqua_app_bar.dart';
import '../../driver/domain/entities/driver_profile.dart';
import '../../trucks/domain/entities/truck.dart';
import '../../trucks/presentation/providers/truck_providers.dart';
import '../domain/repositories/organization_repository.dart';
import 'providers/organization_providers.dart';

/// A truck has no independent identity in the schema — `trucks/{uid}` is
/// created automatically the first time its driver starts a trip, keyed
/// by the same uid as `drivers/{uid}`. This screen is therefore a merge
/// of live truck state (status/load/speed, from [trucksStreamProvider])
/// with the driver's static truck attributes (plate/capacity, from
/// [allDriversProvider]) — one row per driver, not per a separately
/// managed "truck" record.
class OrgTruckManagementScreen extends ConsumerWidget {
  const OrgTruckManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(allDriversProvider);
    final trucksAsync = ref.watch(trucksStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: const AquaAppBar(title: 'إدارة الشاحنات'),
      body: driversAsync.when(
        data: (drivers) {
          if (drivers.isEmpty) {
            return Center(
              child: Text(
                  'لا توجد شاحنات مسجّلة بعد (تُنشأ تلقائيًا عند تسجيل سائق)',
                  style: GoogleFonts.cairo(color: AppColors.textMuted),
                  textAlign: TextAlign.center),
            );
          }
          final trucksById = {
            for (final t in trucksAsync.valueOrNull ?? <Truck>[]) t.id: t,
          };

          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: drivers.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (_, i) => _TruckCard(
              driver: drivers[i],
              truck: trucksById[drivers[i].uid],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('تعذّر تحميل بيانات الشاحنات',
              style: GoogleFonts.cairo(color: AppColors.danger)),
        ),
      ),
    );
  }
}

class _TruckCard extends StatelessWidget {
  final DriverProfile driver;
  final Truck? truck;

  const _TruckCard({required this.driver, this.truck});

  @override
  Widget build(BuildContext context) {
    final isLive = truck != null;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: (isLive ? AppColors.success : AppColors.textMuted)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_shipping_outlined,
                    color: isLive ? AppColors.success : AppColors.textMuted,
                    size: 20.w),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        driver.truckPlateNumber.isEmpty
                            ? 'بلا رقم لوحة'
                            : driver.truckPlateNumber,
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w700, fontSize: 14.sp)),
                    Text('السائق: ${driver.fullName}',
                        style: GoogleFonts.cairo(
                            fontSize: 11.sp, color: AppColors.textMuted)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _showEditSheet(context, driver),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              _chip(Icons.water_drop_outlined,
                  'السعة: ${driver.truckCapacity.toStringAsFixed(0)} لتر'),
              if (isLive) ...[
                _chip(Icons.opacity_outlined,
                    'الحالي: ${truck!.currentLoad.toStringAsFixed(0)} لتر'),
                _chip(Icons.circle, truck!.isActive ? 'نشطة' : 'خاملة'),
              ] else
                _chip(Icons.pause_circle_outline, 'لم تبدأ أي رحلة بعد'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.w, color: AppColors.textMuted),
            SizedBox(width: 4.w),
            Text(label, style: GoogleFonts.cairo(fontSize: 11.sp)),
          ],
        ),
      );

  void _showEditSheet(BuildContext context, DriverProfile driver) {
    final plateCtrl = TextEditingController(text: driver.truckPlateNumber);
    final capacityCtrl =
        TextEditingController(text: driver.truckCapacity.toStringAsFixed(0));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تعديل بيانات الشاحنة',
                  style: GoogleFonts.cairo(
                      fontSize: 16.sp, fontWeight: FontWeight.w700)),
              SizedBox(height: 16.h),
              TextField(
                controller: plateCtrl,
                decoration: const InputDecoration(
                  labelText: 'رقم اللوحة',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: capacityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعة (لتر)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: () async {
                    final plate = plateCtrl.text.trim();
                    final capacity = double.tryParse(capacityCtrl.text.trim());
                    if (plate.isEmpty || capacity == null || capacity <= 0)
                      return;

                    final result =
                        await GetIt.I<OrganizationRepository>().updateTruckInfo(
                      driverUid: driver.uid,
                      truckPlateNumber: plate,
                      truckCapacity: capacity,
                    );
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('حفظ',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
