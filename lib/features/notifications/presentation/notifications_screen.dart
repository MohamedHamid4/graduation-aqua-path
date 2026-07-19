import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../domain/entities/notification_item.dart';
import 'providers/notification_history_provider.dart';

enum _Filter { all, unread }

/// Real received-notification history — replaces what used to be a fixed
/// `const` list of five fabricated cards. See [notificationHistoryProvider]
/// for the Firestore-backed source and push_notification_service.dart for
/// where these records are actually written on FCM receipt.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationHistoryProvider);
    final all = notificationsAsync.valueOrNull ?? const <NotificationItem>[];
    final unreadCount = all.where((n) => !n.read).length;
    final visible =
        _filter == _Filter.unread ? all.where((n) => !n.read).toList() : all;

    final isLoading =
        notificationsAsync.isLoading && !notificationsAsync.hasValue;
    final hasError = notificationsAsync.hasError;
    final isMarkingAll = ref.watch(notificationActionsProvider);

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
                        AppStrings.notificationsTitle,
                        style: GoogleFonts.cairo(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: unreadCount == 0 || isMarkingAll
                            ? null
                            : () => ref
                                .read(notificationActionsProvider.notifier)
                                .markAllRead(),
                        child: Text(
                          AppStrings.notificationsMarkAllRead,
                          style: GoogleFonts.cairo(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: unreadCount == 0
                                ? AppColors.textMuted
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                  SizedBox(height: 8.h),
                  _FilterTabs(
                    filter: _filter,
                    allCount: all.length,
                    unreadCount: unreadCount,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // ── Notification list ─────────────────────────
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : hasError
                      ? Center(
                          child: Text(
                            'تعذّر تحميل الإشعارات',
                            style: GoogleFonts.cairo(color: AppColors.danger),
                          ),
                        )
                      : visible.isEmpty
                          ? Center(
                              child: Text(
                                AppStrings.notificationsEmpty,
                                style: GoogleFonts.cairo(
                                  fontSize: 13.sp,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 4.h,
                              ),
                              itemCount: visible.length,
                              itemBuilder: (context, i) => Padding(
                                padding: EdgeInsets.only(bottom: 8.h),
                                child: _NotifItem(item: visible[i])
                                    .animate(
                                        delay: Duration(
                                            milliseconds: 80 + i * 60))
                                    .fadeIn(duration: 300.ms),
                              ),
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
  final _Filter filter;
  final int allCount;
  final int unreadCount;
  final ValueChanged<_Filter> onChanged;

  const _FilterTabs({
    required this.filter,
    required this.allCount,
    required this.unreadCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabChip(
          AppStrings.notificationsAll,
          allCount,
          active: filter == _Filter.all,
          onTap: () => onChanged(_Filter.all),
        ),
        SizedBox(width: 8.w),
        _TabChip(
          AppStrings.notificationsUnread,
          unreadCount,
          active: filter == _Filter.unread,
          onTap: () => onChanged(_Filter.unread),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _TabChip(
    this.label,
    this.count, {
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}

// ── Notification item ────────────────────────────────────────────────────────

class _NotifItem extends ConsumerWidget {
  final NotificationItem item;

  const _NotifItem({required this.item});

  ({IconData icon, Color color}) get _style => switch (item.type) {
        'delivery_confirmed' => (
            icon: Iconsax.tick_circle,
            color: AppColors.success,
          ),
        'org_broadcast' => (icon: Iconsax.info_circle, color: AppColors.info),
        _ => (icon: Iconsax.notification, color: AppColors.textMuted),
      };

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = _style;

    return GestureDetector(
      onTap: item.read
          ? null
          : () => ref
              .read(notificationActionsProvider.notifier)
              .markRead(item.id),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.read
                ? AppColors.borderDefault
                : style.color.withValues(alpha: 0.4),
            width: item.read ? 1.0 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(style.icon, color: style.color, size: 20.w),
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
                          item.title,
                          style: GoogleFonts.cairo(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo(item.receivedAt),
                        style: GoogleFonts.cairo(
                          fontSize: 10.sp,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    item.body,
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
      ),
    );
  }
}
