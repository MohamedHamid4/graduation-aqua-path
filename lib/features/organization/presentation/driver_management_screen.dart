import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/aqua_app_bar.dart';
import '../../driver/domain/entities/driver_profile.dart';
import '../domain/entities/service_area.dart';
import '../domain/repositories/organization_repository.dart';
import 'providers/organization_providers.dart';

class OrgDriverManagementScreen extends ConsumerStatefulWidget {
  const OrgDriverManagementScreen({super.key});

  @override
  ConsumerState<OrgDriverManagementScreen> createState() =>
      _OrgDriverManagementScreenState();
}

enum _DriverStatusFilter { all, active, inactive }

class _OrgDriverManagementScreenState
    extends ConsumerState<OrgDriverManagementScreen> {
  String _query = '';
  _DriverStatusFilter _filter = _DriverStatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(allDriversProvider);
    final areasAsync = ref.watch(allAreasProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: const AquaAppBar(title: 'إدارة السائقين'),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 8.w),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو رقم اللوحة...',
                hintStyle: GoogleFonts.cairo(fontSize: 13.sp),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                _FilterChip(
                  label: 'الكل',
                  selected: _filter == _DriverStatusFilter.all,
                  onTap: () =>
                      setState(() => _filter = _DriverStatusFilter.all),
                ),
                SizedBox(width: 8.w),
                _FilterChip(
                  label: 'نشط',
                  selected: _filter == _DriverStatusFilter.active,
                  onTap: () =>
                      setState(() => _filter = _DriverStatusFilter.active),
                ),
                SizedBox(width: 8.w),
                _FilterChip(
                  label: 'موقوف',
                  selected: _filter == _DriverStatusFilter.inactive,
                  onTap: () =>
                      setState(() => _filter = _DriverStatusFilter.inactive),
                ),
              ],
            ),
          ),
          Expanded(
            child: driversAsync.when(
              data: (drivers) {
                final filtered = drivers.where((d) {
                  final matchesQuery = _query.isEmpty ||
                      d.fullName.contains(_query) ||
                      d.truckPlateNumber.contains(_query);
                  final matchesFilter = switch (_filter) {
                    _DriverStatusFilter.all => true,
                    _DriverStatusFilter.active => d.isActive,
                    _DriverStatusFilter.inactive => !d.isActive,
                  };
                  return matchesQuery && matchesFilter;
                }).toList()
                  ..sort((a, b) => a.fullName.compareTo(b.fullName));

                if (drivers.isEmpty) {
                  return Center(
                    child: Text('لا يوجد سائقون مسجّلون بعد',
                        style: GoogleFonts.cairo(color: AppColors.textMuted)),
                  );
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Text('لا توجد نتائج مطابقة',
                        style: GoogleFonts.cairo(color: AppColors.textMuted)),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.all(16.w),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) => _DriverCard(
                    driver: filtered[i],
                    areas: areasAsync.valueOrNull ?? [],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('تعذّر تحميل بيانات السائقين',
                    style: GoogleFonts.cairo(color: AppColors.danger)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends ConsumerWidget {
  final DriverProfile driver;
  final List<ServiceArea> areas;

  const _DriverCard({required this.driver, required this.areas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: driver.isActive
              ? AppColors.success.withValues(alpha: 0.2)
              : AppColors.danger.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20.w,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: driver.profilePictureUrl != null
                    ? NetworkImage(driver.profilePictureUrl!)
                    : null,
                child: driver.profilePictureUrl == null
                    ? Icon(Icons.person_outline, color: AppColors.primary)
                    : null,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.fullName,
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w700, fontSize: 14.sp)),
                    Text(driver.phone,
                        style: GoogleFonts.cairo(
                            fontSize: 12.sp, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Switch(
                value: driver.isActive,
                activeColor: AppColors.success,
                onChanged: (v) async {
                  final result =
                      await GetIt.I<OrganizationRepository>().setDriverActive(
                    driverUid: driver.uid,
                    active: v,
                  );
                  if (context.mounted) {
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
                },
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              _chip(Icons.local_shipping_outlined, driver.truckPlateNumber),
              _chip(Icons.badge_outlined, driver.licenseNumber),
              _chip(
                  Icons.map_outlined,
                  driver.assignedArea.isEmpty
                      ? 'بدون منطقة'
                      : driver.assignedArea),
            ],
          ),
          if (areas.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                label: Text('تعيين منطقة',
                    style: GoogleFonts.cairo(fontSize: 12.sp)),
                onPressed: () => _showAreaPicker(context, ref),
              ),
            ),
          ],
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

  void _showAreaPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: areas
              .map((area) => ListTile(
                    title: Text(area.name, style: GoogleFonts.cairo()),
                    onTap: () async {
                      final sheetContext = context;
                      Navigator.of(context).pop();
                      final result = await GetIt.I<OrganizationRepository>()
                          .assignDriverToArea(
                        driverUid: driver.uid,
                        areaId: area.id,
                      );
                      if (sheetContext.mounted) {
                        result.fold(
                          (failure) =>
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text(failure.message),
                              backgroundColor: AppColors.danger,
                            ),
                          ),
                          (_) {},
                        );
                      }
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryDark : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
