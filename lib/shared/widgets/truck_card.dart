import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../features/trucks/domain/entities/eta_result.dart';
import '../../features/trucks/domain/entities/truck.dart';
import '../../shared/services/eta_service.dart';

class TruckCard extends StatelessWidget {
  final Truck truck;
  final EtaResult eta;
  final EtaService etaService;
  final VoidCallback onTap;

  const TruckCard({
    super.key,
    required this.truck,
    required this.eta,
    required this.etaService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isClose = eta.etaMinutes < 15;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isClose
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.borderDefault,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    gradient: truck.isActive ? AppColors.primaryGradient : null,
                    color: truck.isActive
                        ? null
                        : AppColors.textMuted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_shipping_rounded,
                    color: truck.isActive ? Colors.white : AppColors.textMuted,
                    size: 22.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        truck.driverName,
                        style: GoogleFonts.cairo(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Icon(
                            Icons.route_rounded,
                            size: 12.w,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 3.w),
                          Flexible(
                            child: Text(
                              truck.routeName,
                              style: GoogleFonts.cairo(
                                fontSize: 11.sp,
                                color: AppColors.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: isClose
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        etaService.formatEta(eta.etaMinutes),
                        style: GoogleFonts.cairo(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: isClose ? AppColors.success : AppColors.accent,
                        ),
                      ),
                      Text(
                        AppStrings.eta,
                        style: GoogleFonts.cairo(
                          fontSize: 9.sp,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Container(height: 1, color: AppColors.borderDefault),
            SizedBox(height: 12.h),
            Row(
              children: [
                _StatItem(
                  icon: Iconsax.location,
                  label: '${eta.distanceKm} كم',
                  color: AppColors.info,
                ),
                _Divider(),
                _StatItem(
                  icon: Iconsax.drop,
                  label: '${(truck.loadPercentage * 100).round()}% حمولة',
                  color: AppColors.primary,
                ),
                _Divider(),
                _StatItem(
                  icon: truck.isActive ? Iconsax.verify : Iconsax.clock,
                  label: truck.isActive ? AppStrings.active : AppStrings.idle,
                  color: truck.isActive ? AppColors.success : AppColors.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.w, color: color),
        SizedBox(width: 4.w),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      color: AppColors.borderDefault,
      margin: EdgeInsets.symmetric(horizontal: 10.w),
    );
  }
}
