import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الإشعارات',
                        style: GoogleFonts.cairo(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'قراءة الكل',
                          style: GoogleFonts.cairo(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                  SizedBox(height: 8.h),
                  _FilterTabs(),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // ── Notification list ─────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: 20.w,
                  vertical: 4.h,
                ),
                children: const [
                  _NotifItem(
                    icon: Iconsax.truck,
                    iconColorKey: _ColorKey.danger,
                    title: 'شاحنة المياه اقتربت!',
                    subtitle: 'شاحنة أحمد محمد على بعد 500 متر من موقعك',
                    time: 'منذ 5 دقائق',
                    isUrgent: true,
                    delay: 200,
                  ),
                  _NotifItem(
                    icon: Iconsax.truck,
                    iconColorKey: _ColorKey.info,
                    title: 'شاحنة في طريقها إليك',
                    subtitle:
                        'شاحنة محمد خالد - المسافة: 3.5 كم - الوصول: 22 دقيقة',
                    time: 'منذ 15 دقيقة',
                    delay: 280,
                  ),
                  _NotifItem(
                    icon: Iconsax.tick_circle,
                    iconColorKey: _ColorKey.success,
                    title: 'تم توصيل المياه لمنطقتك',
                    subtitle: 'الشجاعية - تم توزيع المياه بنجاح',
                    time: 'منذ ساعتين',
                    delay: 360,
                  ),
                  _NotifItem(
                    icon: Iconsax.info_circle,
                    iconColorKey: _ColorKey.info,
                    title: 'تحديث جدول التوزيع',
                    subtitle:
                        'تم تعديل موعد مرور الشاحنة غداً إلى الساعة 8 صباحاً',
                    time: 'منذ 4 ساعات',
                    delay: 440,
                  ),
                  _NotifItem(
                    icon: Iconsax.warning_2,
                    iconColorKey: _ColorKey.warning,
                    title: 'تنبيه: شاحنة غير متاحة',
                    subtitle: 'شاحنة خالد عمر متوقفة حالياً للصيانة',
                    time: 'أمس',
                    delay: 520,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter tabs ──────────────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabChip('الكل', 5, active: true),
        SizedBox(width: 8.w),
        _TabChip('عاجلة', 1),
        SizedBox(width: 8.w),
        _TabChip('معلومات', 4),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;

  const _TabChip(this.label, this.count, {this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.borderDefault,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
          SizedBox(width: 5.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.bgTertiary,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.cairo(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification item ────────────────────────────────────────────────────────

enum _ColorKey { danger, info, success, warning }

class _NotifItem extends StatelessWidget {
  final IconData icon;
  final _ColorKey iconColorKey;
  final String title;
  final String subtitle;
  final String time;
  final bool isUrgent;
  final int delay;

  const _NotifItem({
    required this.icon,
    required this.iconColorKey,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isUrgent = false,
    required this.delay,
  });

  Color get _color {
    return switch (iconColorKey) {
      _ColorKey.danger => AppColors.danger,
      _ColorKey.info => AppColors.info,
      _ColorKey.success => AppColors.success,
      _ColorKey.warning => AppColors.warning,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isUrgent ? color.withValues(alpha: 0.4) : AppColors.borderDefault,
          width: isUrgent ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20.w),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.cairo(
                        fontSize: 10.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: delay)).fadeIn(duration: 400.ms);
  }
}
