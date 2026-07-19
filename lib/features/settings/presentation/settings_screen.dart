import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_names.dart';
import '../../../shared/providers/household_provider.dart';
import '../../../shared/providers/notification_prefs_provider.dart';
import '../../../shared/services/priority_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    final householdAsync = ref.watch(currentHouseholdProvider);
    final household = householdAsync.valueOrNull;
    final priorityLevel = household != null
        ? GetIt.I<PriorityService>().getPriorityLevel(household.priorityScore)
        : null;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 40.h),
          children: [
            Text(
              AppStrings.settingsTitle,
              style: GoogleFonts.cairo(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ).animate().fadeIn(duration: 400.ms),
            SizedBox(height: 18.h),
            Container(
              padding: EdgeInsets.all(18.w),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56.w,
                    height: 56.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Icon(Icons.person_rounded,
                        color: Colors.white, size: 28.w),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            String line1;
                            String line2 = '';

                            if (householdAsync.isLoading &&
                                !householdAsync.hasValue) {
                              line1 = 'جاري تحميل البيانات...';
                            } else if (householdAsync.hasError) {
                              line1 = 'تعذر تحميل البيانات';
                            } else if (household == null) {
                              line1 = 'لم يتم تسجيل الأسرة';
                            } else {
                              line1 = household.familyName;
                              line2 =
                                  '${household.areaName} • ${household.householdSize} أفراد';
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line1,
                                  style: GoogleFonts.cairo(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                if (line2.isNotEmpty)
                                  Text(
                                    line2,
                                    style: GoogleFonts.cairo(
                                      fontSize: 12.sp,
                                      color: Colors.white70,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        if (priorityLevel != null) ...[
                          SizedBox(height: 4.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'أولوية: ${priorityLevel.labelAr}',
                              style: GoogleFonts.cairo(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Iconsax.edit,
                    color: Colors.white70,
                    size: 18.w,
                  ),
                ],
              ),
            )
                .animate(delay: 100.ms)
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.1, end: 0),
            SizedBox(height: 24.h),
            const _SectionTitle(AppStrings.settingsGeneral),
            SizedBox(height: 8.h),
            _Tile(
              icon: Iconsax.notification,
              title: AppStrings.settingsNotifications,
              subtitle: prefs.enabled
                  ? AppStrings.settingsNotificationsSubtitle
                  : 'التنبيهات متوقفة',
              trailing: Switch(
                value: prefs.enabled,
                activeThumbColor: AppColors.primary,
                onChanged: (value) => ref
                    .read(notificationPrefsProvider.notifier)
                    .setEnabled(value: value),
              ),
            ),
            _Tile(
              icon: Iconsax.map,
              title: AppStrings.settingsRadius,
              subtitle: 'المسافة: ${prefs.radiusMeters} متر',
              onTap: () => _pickRadius(context, ref, prefs.radiusMeters),
            ),
            SizedBox(height: 18.h),
            const _SectionTitle(AppStrings.settingsFamily),
            SizedBox(height: 8.h),
            _Tile(
              icon: Iconsax.home,
              title: AppStrings.settingsEditFamily,
              subtitle: AppStrings.settingsEditFamilySubtitle,
              onTap: () => context.push(RouteNames.register),
            ),
            _Tile(
              icon: Iconsax.archive_tick,
              title: AppStrings.settingsHistory,
              subtitle: AppStrings.settingsHistorySubtitle,
              onTap: () => context.push(RouteNames.schedule),
            ),
            SizedBox(height: 18.h),
            const _SectionTitle(AppStrings.settingsAbout),
            SizedBox(height: 8.h),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.hasData
                    ? 'الإصدار ${snapshot.data!.version}'
                    : 'الإصدار 1.0.0';
                return _Tile(
                  icon: Iconsax.info_circle,
                  title: AppStrings.settingsAboutApp,
                  subtitle: version,
                  onTap: () => _showAbout(context, version),
                );
              },
            ),
            _Tile(
              icon: Iconsax.message_question,
              title: AppStrings.settingsHelp,
              subtitle: AppStrings.settingsHelpSubtitle,
              onTap: () => _showHelp(context),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                icon: const Icon(Iconsax.logout, size: 18),
                label: Text(
                  AppStrings.settingsLogout,
                  style: GoogleFonts.cairo(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ).animate(delay: 600.ms).fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRadius(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        decoration: const BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              AppStrings.settingsRadius,
              style: GoogleFonts.cairo(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            ...kNotificationRadiusOptions.map((meters) {
              final selected = meters == current;
              return Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Material(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(sheetContext, meters),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textMuted,
                            size: 20.w,
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            '$meters متر',
                            style: GoogleFonts.cairo(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );

    if (chosen != null) {
      await ref
          .read(notificationPrefsProvider.notifier)
          .setRadiusMeters(chosen);
    }
  }

  void _showAbout(BuildContext context, String version) {
    showAboutDialog(
      context: context,
      applicationName: AppStrings.appName,
      applicationVersion: version,
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.water_drop_rounded, color: Colors.white),
      ),
      children: [
        Text(
          'تطبيق تتبع شاحنات المياه في قطاع غزة، يعرض المواقع لحظياً '
          'ويحسب وقت الوصول المتوقع ويرتب الأسر حسب أولوية الحاجة.',
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppStrings.settingsHelp,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'لأي استفسار أو مشكلة تتعلق بتوصيل المياه أو استخدام '
          'التطبيق، يرجى التواصل معنا عبر البريد الإلكتروني:\n'
          'support@aquapath.app',
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'حسناً',
              style: GoogleFonts.cairo(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'تسجيل الخروج',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'هل تريد تسجيل الخروج من حسابك؟',
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'تسجيل الخروج',
              style: GoogleFonts.cairo(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    // Signing out flips authStateProvider to null, which
    // GoRouterRefreshStream picks up immediately — the router's redirect
    // callback sends the user to /login on its own, no manual nav needed.
    if (confirmed == true) {
      await ref.read(authFormProvider.notifier).signOut();
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.cairo(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      child: Material(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Row(
              children: [
                Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 18.w),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.cairo(
                          fontSize: 10.sp,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_left,
                      size: 18.w,
                      color: AppColors.textMuted,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
