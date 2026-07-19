import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import 'providers/organization_providers.dart';

/// The Organization's landing screen: headline operational numbers plus
/// entry points into driver/resident/area management, live monitoring,
/// and settings. Reports export is CSV today (see [OperationsReport]) —
/// PDF/styled Excel are a documented follow-up, not silently missing.
class OrgDashboardScreen extends ConsumerWidget {
  const OrgDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driversAsync = ref.watch(allDriversProvider);
    final householdsAsync = ref.watch(allHouseholdsProvider);
    final areasAsync = ref.watch(allAreasProvider);
    final reportAsync = ref.watch(todayReportProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: Text('لوحة المؤسسة',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700, color: Colors.white)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => context.push(RouteNames.orgSettings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayReportProvider);
        },
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12.w,
              crossAxisSpacing: 12.w,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  icon: Icons.local_shipping_outlined,
                  label: 'السائقون النشطون',
                  value: driversAsync.maybeWhen(
                    data: (d) =>
                        '${d.where((e) => e.isActive).length}/${d.length}',
                    orElse: () => '—',
                  ),
                  color: AppColors.primary,
                ),
                _StatCard(
                  icon: Icons.home_outlined,
                  label: 'الأسر المسجّلة',
                  value: householdsAsync.maybeWhen(
                    data: (h) => '${h.length}',
                    orElse: () => '—',
                  ),
                  color: AppColors.success,
                ),
                _StatCard(
                  icon: Icons.map_outlined,
                  label: 'المناطق',
                  value: areasAsync.maybeWhen(
                    data: (a) => '${a.length}',
                    orElse: () => '—',
                  ),
                  color: AppColors.accent,
                ),
                _StatCard(
                  icon: Icons.water_drop_outlined,
                  label: 'لترات موزّعة اليوم',
                  value: reportAsync.maybeWhen(
                    data: (r) =>
                        r?.totalLitersDelivered.toStringAsFixed(0) ?? '0',
                    orElse: () => '—',
                  ),
                  color: AppColors.info,
                ),
              ],
            ),
            SizedBox(height: 20.h),
            _MenuTile(
              icon: Icons.groups_outlined,
              title: 'إدارة السائقين',
              subtitle: 'تفعيل، تعطيل، وتعيين المناطق',
              onTap: () => context.push(RouteNames.orgDrivers),
            ),
            _MenuTile(
              icon: Icons.home_outlined,
              title: 'إدارة السكان',
              subtitle: 'عرض الأسر المسجّلة وبيانات الأولوية',
              onTap: () => context.push(RouteNames.orgResidents),
            ),
            _MenuTile(
              icon: Icons.local_shipping_outlined,
              title: 'إدارة الشاحنات',
              subtitle: 'عرض وتعديل رقم اللوحة والسعة',
              onTap: () => context.push(RouteNames.orgTrucks),
            ),
            _MenuTile(
              icon: Icons.event_note_outlined,
              title: 'إدارة الجداول',
              subtitle: 'جدولة رحلات التوزيع وإلغاؤها',
              onTap: () => context.push(RouteNames.orgSchedule),
            ),
            _MenuTile(
              icon: Icons.map_outlined,
              title: 'إدارة المناطق',
              subtitle: 'إنشاء المناطق وتعديلها وحذفها',
              onTap: () => context.push(RouteNames.orgAreas),
            ),
            _MenuTile(
              icon: Icons.campaign_outlined,
              title: 'مركز الإشعارات',
              subtitle: 'إرسال إشعارات لمنطقة أو لجميع المناطق',
              onTap: () => context.push(RouteNames.orgNotifications),
            ),
            _MenuTile(
              icon: Icons.map_outlined,
              title: 'المراقبة الحية',
              subtitle: 'مواقع الشاحنات والسائقين ومواقف الانتظار',
              onTap: () => context.push(RouteNames.orgLiveMonitoring),
            ),
            _MenuTile(
              icon: Icons.summarize_outlined,
              title: 'التقارير والتحليلات',
              subtitle:
                  'تقارير يومية وأسبوعية وشهرية، وإحصائيات السائقين والمناطق',
              onTap: () => context.push(RouteNames.orgReports),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22.w),
          Text(value,
              style: GoogleFonts.cairo(
                  fontSize: 22.sp, fontWeight: FontWeight.w800)),
          Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 11.sp, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primaryDark),
        title: Text(title,
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700, fontSize: 14.sp)),
        subtitle: Text(subtitle,
            style:
                GoogleFonts.cairo(fontSize: 11.sp, color: AppColors.textMuted)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      ),
    );
  }
}
