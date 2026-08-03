import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/errors/failures.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/aqua_error_widget.dart';
import '../../../core/widgets/aqua_shimmer.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../trucks/domain/entities/truck.dart';
import '../domain/entities/driver_route.dart';
import 'providers/driver_routes_provider.dart';
import 'providers/driver_status_providers.dart';

/// جدول العمل — the driver's work schedule: today's assigned delivery
/// routes, each launching the live route map when tapped.
class DriverScheduleScreen extends ConsumerWidget {
  const DriverScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(driverRoutesProvider);
    final truckAsync = ref.watch(currentDriverTruckProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref),
            Expanded(
              child: routesAsync.when(
                data: (routes) => ListView(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
                  children: [
                    // ── Delivery Statistics Card ──
                    truckAsync
                        .when(
                          data: (truck) => truck != null
                              ? _WaterDistributionStatsCard(truck: truck)
                              : const SizedBox.shrink(),
                          loading: () => AquaShimmer(
                            height: 180,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                        )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),

                    SizedBox(height: 24.h),

                    if (routes.isEmpty)
                      const AquaErrorWidget.empty(
                        title: 'لا توجد رحلات مجدولة',
                        message: 'سيتم عرض رحلاتك هنا عند إسنادها من المشرف',
                      )
                    else ...[
                      Text(
                        'رحلات اليوم',
                        style: GoogleFonts.cairo(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      ...routes.asMap().entries.map(
                            (e) => Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: _RouteCard(route: e.value)
                                  .animate(
                                    delay: Duration(
                                      milliseconds: 100 * e.key,
                                    ),
                                  )
                                  .fadeIn(duration: 350.ms)
                                  .slideY(begin: 0.06, end: 0),
                            ),
                          ),
                    ],
                  ],
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => e is NetworkFailure
                    ? AquaErrorWidget.network(
                        onRetry: () => ref.invalidate(driverRoutesProvider),
                      )
                    : AquaErrorWidget(
                        title: 'تعذّر تحميل الرحلات',
                        message: e is Failure
                            ? FailureMessages.fromFailure(e)
                            : 'حدث خطأ غير متوقع. حاول مجدداً.',
                        onRetry: () => ref.invalidate(driverRoutesProvider),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 20.w,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جدول عملي',
                  style: GoogleFonts.cairo(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'AquaPath — واجهة السائق',
                  style: GoogleFonts.cairo(
                    fontSize: 10.sp,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.person_outline_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: () => context.push(RouteNames.driverSettings),
          ),
          IconButton(
            icon: Icon(
              Icons.logout_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: () async {
              await ref.read(authFormProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _WaterDistributionStatsCard extends StatelessWidget {
  final Truck truck;

  const _WaterDistributionStatsCard({required this.truck});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المياه الموزعة',
            style: GoogleFonts.cairo(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 20.h),
          _StatRow(
              label: 'حمولة الشاحنة',
              value: '${truck.capacity.toStringAsFixed(0)} لتر'),
          Divider(height: 24.h, color: colorScheme.outlineVariant),
          _StatRow(
              label: 'تم توزيعه',
              value: '${truck.distributedAmount.toStringAsFixed(0)} لتر',
              valueColor: colorScheme.primary),
          Divider(height: 24.h, color: colorScheme.outlineVariant),
          _StatRow(
              label: 'المتبقي',
              value: '${truck.currentLoad.toStringAsFixed(0)} لتر'),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'نسبة التوزيع',
                style: GoogleFonts.cairo(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${(truck.distributionPercentage * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: truck.distributionPercentage,
              minHeight: 8.h,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: valueColor ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _RouteCard extends ConsumerWidget {
  final DriverRoute route;

  const _RouteCard({required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color, icon) = switch (route.status) {
      'in_progress' => (
          'جارية الآن',
          AppColors.success,
          Icons.navigation_rounded
        ),
      'completed' => (
          'مكتملة',
          colorScheme.onSurfaceVariant,
          Icons.check_circle_rounded
        ),
      _ => ('مجدولة', colorScheme.primary, Icons.schedule_rounded),
    };

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: route.isInProgress
              ? AppColors.success.withValues(alpha: 0.4)
              : colorScheme.outlineVariant,
          width: route.isInProgress ? 1.6 : 1,
        ),
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
                    Text(
                      'الوجهة: ${route.areaName}',
                      style: GoogleFonts.cairo(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '⏰ ${route.timeSlot}  •  ${route.expectedLiters.toStringAsFixed(0)} لتر',
                      style: GoogleFonts.cairo(
                        fontSize: 11.sp,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (!route.isCompleted) ...[
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 42.h,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/driver/map/${route.id}'),
                icon: Icon(
                  route.isInProgress
                      ? Icons.map_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                ),
                label: Text(
                  route.isInProgress
                      ? 'متابعة الرحلة على الخريطة'
                      : 'بدء الرحلة',
                  style: GoogleFonts.cairo(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: route.isInProgress
                      ? AppColors.success
                      : colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
