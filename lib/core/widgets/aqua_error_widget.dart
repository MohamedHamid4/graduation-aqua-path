import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class AquaErrorWidget extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;

  const AquaErrorWidget({
    super.key,
    this.title = 'حدث خطأ',
    this.message,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  const AquaErrorWidget.network({
    super.key,
    this.onRetry,
  })  : title = 'تعذّر تحميل البيانات',
        message = 'تحقق من اتصالك بالإنترنت وحاول مجدداً',
        icon = Icons.wifi_off_rounded;

  const AquaErrorWidget.empty({
    super.key,
    this.title = 'لا توجد بيانات',
    this.message,
    this.onRetry,
  }) : icon = Icons.inbox_rounded;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38.w, color: AppColors.danger),
            )
                .animate()
                .scale(
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.6, 0.6),
                )
                .fadeIn(duration: 400.ms),
            SizedBox(height: 20.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ).animate(delay: 150.ms).fadeIn(duration: 400.ms),
            if (message != null) ...[
              SizedBox(height: 8.h),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ).animate(delay: 250.ms).fadeIn(duration: 400.ms),
            ],
            if (onRetry != null) ...[
              SizedBox(height: 24.h),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'إعادة المحاولة',
                  style: GoogleFonts.cairo(
                      fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ).animate(delay: 350.ms).fadeIn(duration: 400.ms),
            ],
          ],
        ),
      ),
    );
  }
}
