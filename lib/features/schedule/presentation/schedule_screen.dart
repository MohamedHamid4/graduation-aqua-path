import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/household_provider.dart';
import '../../../shared/providers/reminder_prefs_provider.dart';
import '../../../shared/services/priority_service.dart';
import '../../driver/domain/entities/driver_route.dart';
import '../../water_delivery/domain/entities/water_delivery.dart';
import '../../water_delivery/presentation/providers/water_delivery_provider.dart';
import 'providers/upcoming_schedule_provider.dart';

const _kArabicMonths = [
  '',
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// Formats a [DateTime] as "12 يونيو" without depending on `intl`'s
/// locale data files (which aren't initialized in this app) — matches
/// the manual Arabic formatting already used throughout this screen.
String _arabicDayMonth(DateTime d) => '${d.day} ${_kArabicMonths[d.month]}';

/// Formats a [DateTime] as "8:15 صباحاً" for the same reason as above.
String _arabicTime(DateTime d) {
  final period = d.hour >= 12 ? 'مساءً' : 'صباحاً';
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  int _selectedDay = DateTime.now().weekday - 1; // 0=Mon…6=Sun
  bool _historyExpanded = false;

  String _arabicDayShort(int weekday) {
    const names = ['', 'إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];
    return names[weekday];
  }

  String _formatDate(DateTime d) => _arabicDayMonth(d);

  String _dayStatus(
    DateTime day,
    List<WaterDelivery> history,
    List<DriverRoute> upcoming,
  ) {
    final today = DateTime.now();
    if (day.isBefore(DateTime(today.year, today.month, today.day))) {
      for (final h in history) {
        if (h.createdAt.day == day.day && h.createdAt.month == day.month) {
          return 'delivered';
        }
      }
      return 'none';
    }
    for (final r in upcoming) {
      if (r.scheduledTime.day == day.day && r.scheduledTime.month == day.month) {
        return 'scheduled';
      }
    }
    return 'none';
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(deliveryReminderProvider);
    final historyAsync = ref.watch(areaWaterDeliveriesProvider);
    final history = historyAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <WaterDelivery>[],
    );
    final isHistoryLoading = historyAsync.isLoading && !historyAsync.hasValue;
    final hasHistoryError = historyAsync.hasError;

    final upcomingAsync = ref.watch(upcomingAreaRoutesProvider);
    final upcoming = upcomingAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <DriverRoute>[],
    );
    final isUpcomingLoading = upcomingAsync.isLoading && !upcomingAsync.hasValue;
    final hasUpcomingError = upcomingAsync.hasError;

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 100.h),
                children: [
                  const _AreaInfoCard()
                      .animate(delay: 100.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.08, end: 0),
                  SizedBox(height: 20.h),
                  _SectionTitle(
                    title: 'التقويم الأسبوعي',
                    subtitle:
                        'أسبوع ${_formatDate(weekStart)} – ${_formatDate(weekDays.last)}',
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    height: 86.h,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 7,
                      itemBuilder: (_, i) {
                        final day = weekDays[i];
                        final status = _dayStatus(day, history, upcoming);
                        final isToday =
                            day.day == now.day && day.month == now.month;
                        final isSelected = _selectedDay == i;
                        return _DayCard(
                          dayShort: _arabicDayShort(day.weekday),
                          dayNum: day.day,
                          status: status,
                          isToday: isToday,
                          isSelected: isSelected,
                          onTap: () => setState(() => _selectedDay = i),
                        );
                      },
                    ),
                  ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                  SizedBox(height: 24.h),
                  const _SectionTitle(title: 'الأيام القادمة'),
                  SizedBox(height: 10.h),
                  if (isUpcomingLoading)
                    const _HistoryLoadingPlaceholder()
                  else if (hasUpcomingError)
                    Text(
                      'تعذّر تحميل جدول التوزيع القادم',
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        color: AppColors.danger,
                      ),
                    )
                  else if (upcoming.isEmpty)
                    Text(
                      'لا توجد توزيعات قادمة مجدولة',
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        color: AppColors.textMuted,
                      ),
                    )
                  else ...[
                    _NextDeliveryCard(route: upcoming.first)
                        .animate(delay: 300.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.06, end: 0),
                    SizedBox(height: 8.h),
                    ...List.generate(
                      upcoming.length - 1,
                      (i) => Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: _UpcomingCard(route: upcoming[i + 1])
                            .animate(
                                delay: Duration(milliseconds: 350 + i * 80))
                            .fadeIn(duration: 400.ms),
                      ),
                    ),
                  ],
                  SizedBox(height: 24.h),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _historyExpanded = !_historyExpanded),
                    child: Row(
                      children: [
                        const _SectionTitle(title: 'سجل التوصيلات السابقة'),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: AppColors.bgTertiary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderDefault),
                          ),
                          child: Text(
                            '${history.length} توصيلات',
                            style: GoogleFonts.cairo(
                              fontSize: 10.sp,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        AnimatedRotation(
                          turns: _historyExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            Icons.expand_more_rounded,
                            size: 20.w,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  if (isHistoryLoading)
                    const _HistoryLoadingPlaceholder()
                  else if (hasHistoryError)
                    Text(
                      'تعذّر تحميل سجل التوصيلات',
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        color: AppColors.danger,
                      ),
                    )
                  else if (history.isEmpty)
                    Text(
                      'لا يوجد سجل توصيلات بعد',
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        color: AppColors.textMuted,
                      ),
                    )
                  else
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Column(
                        children: (_historyExpanded
                                ? history
                                : history.take(2).toList())
                            .map((h) => Padding(
                                  padding: EdgeInsets.only(bottom: 6.h),
                                  child: _HistoryTile(entry: h),
                                ))
                            .toList(),
                      ),
                    ),
                  SizedBox(height: 24.h),
                  _ReminderToggle(
                    enabled: reminders,
                    onTap: () => ref
                        .read(deliveryReminderProvider.notifier)
                        .setEnabled(value: !reminders),
                  ).animate(delay: 500.ms).fadeIn(duration: 400.ms),
                  SizedBox(height: 14.h),
                  SizedBox(
                    width: double.infinity,
                    height: 54.h,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Iconsax.map, size: 20),
                      label: Text(
                        'متابعة إلى الخريطة',
                        style: GoogleFonts.cairo(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: AppColors.success.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ).animate(delay: 600.ms).fadeIn(duration: 400.ms).slideY(
                        begin: 0.15,
                        end: 0,
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final household = ref.watch(currentHouseholdProvider).valueOrNull;
    final areaLabel = household?.areaName.isNotEmpty == true
        ? household!.areaName
        : '—';
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Icon(
                Icons.arrow_back_ios_rounded,
                size: 16.w,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جدول وصول الشاحنات',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'المنطقة: $areaLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Image.asset(
            'assets/images/aquapath_logo.png',
            width: 38.w,
            height: 38.w,
            fit: BoxFit.contain,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: GoogleFonts.cairo(
              fontSize: 11.sp,
              color: AppColors.textMuted,
            ),
          ),
      ],
    );
  }
}

class _AreaInfoCard extends ConsumerWidget {
  const _AreaInfoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(currentHouseholdProvider).valueOrNull;
    final areaLabel =
        household?.areaName.isNotEmpty == true ? household!.areaName : '—';
    final priorityLevel = household != null
        ? GetIt.I<PriorityService>().getPriorityLevel(household.priorityScore)
        : null;
    final priorityColor = priorityLevel != null
        ? Color(priorityLevel.colorValue)
        : AppColors.textMuted;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              gradient: AppColors.greenGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.home_rounded, color: Colors.white, size: 24.w),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'منطقتك: $areaLabel',
                  style: GoogleFonts.cairo(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 5.h),
                Row(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: priorityColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 11.w,
                            color: priorityColor,
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            priorityLevel != null
                                ? 'أولويتك: ${priorityLevel.labelAr}'
                                : 'أولويتك: —',
                            style: GoogleFonts.cairo(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: priorityColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '3 مرات أسبوعياً',
                      style: GoogleFonts.cairo(
                        fontSize: 11.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final String dayShort;
  final int dayNum;
  final String status;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCard({
    required this.dayShort,
    required this.dayNum,
    required this.status,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color bgColor;
    final Color textColor;
    final Widget statusIcon;

    if (isSelected || isToday) {
      borderColor = AppColors.primary;
      bgColor = AppColors.primary.withValues(alpha: 0.08);
      textColor = AppColors.primary;
    } else {
      borderColor = AppColors.borderDefault;
      bgColor = AppColors.bgPrimary;
      textColor = AppColors.textSecondary;
    }

    switch (status) {
      case 'delivered':
        statusIcon = Icon(Icons.check_circle_rounded,
            size: 14.w, color: AppColors.success);
      case 'scheduled':
        statusIcon =
            Icon(Icons.schedule_rounded, size: 14.w, color: AppColors.primary);
      default:
        statusIcon = Icon(Icons.remove, size: 14.w, color: AppColors.textMuted);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52.w,
        margin: EdgeInsets.only(left: 8.w),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isSelected || isToday ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayShort,
              style: GoogleFonts.cairo(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              '$dayNum',
              style: GoogleFonts.cairo(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: isSelected || isToday
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            statusIcon,
          ],
        ),
      ),
    );
  }
}

class _NextDeliveryCard extends ConsumerWidget {
  final DriverRoute route;

  const _NextDeliveryCard({required this.route});

  static String _arabicDay(int wd) {
    const n = [
      '',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    return n[wd];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverName =
        ref.watch(driverNameProvider(route.driverUid)).valueOrNull ?? '';

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: AppColors.greenGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      size: 13.w,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'الموعد القادم',
                      style: GoogleFonts.cairo(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${route.expectedLiters.toStringAsFixed(0)} لتر',
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(Icons.local_shipping_rounded,
                  size: 32.w, color: Colors.white),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_arabicDay(route.scheduledTime.weekday)}، '
                      '${_arabicDayMonth(route.scheduledTime)}',
                      style: GoogleFonts.cairo(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 12.w, color: Colors.white70),
                        SizedBox(width: 4.w),
                        Text(
                          route.timeSlot,
                          style: GoogleFonts.cairo(
                            fontSize: 12.sp,
                            color: Colors.white70,
                          ),
                        ),
                        if (driverName.isNotEmpty) ...[
                          SizedBox(width: 10.w),
                          Icon(Icons.person_rounded,
                              size: 12.w, color: Colors.white70),
                          SizedBox(width: 4.w),
                          Text(
                            driverName,
                            style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends ConsumerWidget {
  final DriverRoute route;

  const _UpcomingCard({required this.route});

  static String _arabicDay(int wd) {
    const n = [
      '',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    return n[wd];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverName =
        ref.watch(driverNameProvider(route.driverUid)).valueOrNull ?? '';

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              color: AppColors.primary,
              size: 22.w,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_arabicDay(route.scheduledTime.weekday)}، '
                  '${_arabicDayMonth(route.scheduledTime)}',
                  style: GoogleFonts.cairo(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  driverName.isNotEmpty
                      ? '⏰ ${route.timeSlot}  •  $driverName'
                      : '⏰ ${route.timeSlot}',
                  style: GoogleFonts.cairo(
                    fontSize: 11.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${route.expectedLiters.toStringAsFixed(0)} ل',
              style: GoogleFonts.cairo(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryLoadingPlaceholder extends StatelessWidget {
  const _HistoryLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (i) => Container(
          margin: EdgeInsets.only(bottom: 6.h),
          height: 52.h,
          decoration: BoxDecoration(
            color: AppColors.bgTertiary,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final WaterDelivery entry;

  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 16.w,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _arabicDayMonth(entry.createdAt),
                  style: GoogleFonts.cairo(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_arabicTime(entry.createdAt)}  •  ${entry.areaName}',
                  style: GoogleFonts.cairo(
                    fontSize: 10.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.amountLiters.toStringAsFixed(0)} لتر',
            style: GoogleFonts.cairo(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _ReminderToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ReminderToggle({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.success.withValues(alpha: 0.06)
              : AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.borderDefault,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                enabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_outlined,
                color: AppColors.success,
                size: 22.w,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفعيل التذكيرات لكل المواعيد',
                    style: GoogleFonts.cairo(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    enabled
                        ? 'مفعّلة — ستصلك إشعارات قبل كل موعد'
                        : 'اضغط لتفعيل الإشعارات التلقائية',
                    style: GoogleFonts.cairo(
                      fontSize: 10.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 46.w,
              height: 26.h,
              decoration: BoxDecoration(
                color: enabled ? AppColors.success : AppColors.borderDefault,
                borderRadius: BorderRadius.circular(13),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                alignment:
                    enabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22.w,
                  height: 22.w,
                  margin: EdgeInsets.symmetric(horizontal: 2.w),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
