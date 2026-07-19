import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/aqua_shimmer.dart';
import '../../../shared/services/eta_service.dart';
import '../../../shared/services/location_service.dart';
import '../domain/entities/eta_result.dart';
import '../domain/entities/truck.dart';
import 'providers/truck_providers.dart';

class TrucksListScreen extends ConsumerStatefulWidget {
  const TrucksListScreen({super.key});

  @override
  ConsumerState<TrucksListScreen> createState() => _TrucksListScreenState();
}

class _TrucksListScreenState extends ConsumerState<TrucksListScreen> {
  String _filter = 'الكل';
  static const _filters = ['الكل', 'نشطة', 'قريبة', 'متوقفة'];

  List<Truck> _applyFilter(
    List<Truck> trucks,
    EtaService eta,
    double userLat,
    double userLng,
  ) {
    switch (_filter) {
      case 'نشطة':
        return trucks.where((t) => t.isActive).toList();
      case 'متوقفة':
        return trucks.where((t) => !t.isActive).toList();
      case 'قريبة':
        return trucks.where((t) {
          final result = eta.calculateEta(
            truckLat: t.latitude,
            truckLng: t.longitude,
            userLat: userLat,
            userLng: userLng,
            averageSpeed: t.averageSpeed,
          );
          return result.distanceKm <= 2.0;
        }).toList();
      default:
        return trucks;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trucksAsync = ref.watch(trucksStreamProvider);
    final etaService = ref.watch(etaServiceProvider);
    final userLocationAsync = ref.watch(userLocationProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title + filters ───────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الشاحنات القريبة',
                    style: GoogleFonts.cairo(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                  SizedBox(height: 12.h),
                  SizedBox(
                    height: 38.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => SizedBox(width: 8.w),
                      itemBuilder: (_, i) {
                        final f = _filters[i];
                        final active = _filter == f;
                        return GestureDetector(
                          onTap: () => setState(() => _filter = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  active ? AppColors.primary : AppColors.bgCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: active
                                    ? AppColors.primary
                                    : AppColors.borderDefault,
                              ),
                            ),
                            child: Text(
                              f,
                              style: GoogleFonts.cairo(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),

            // ── List ──────────────────────────────────────
            Expanded(
              child: trucksAsync.when(
                data: (trucks) {
                  return userLocationAsync.when(
                    data: (userPos) => _TruckListView(
                      trucks: _applyFilter(
                        trucks,
                        etaService,
                        userPos.lat,
                        userPos.lng,
                      ),
                      userLat: userPos.lat,
                      userLng: userPos.lng,
                      etaService: etaService,
                    ),
                    loading: () => const AquaShimmerList(),
                    // LocationService always resolves with a fallback
                    // coordinate rather than throwing, but render safely
                    // with the Gaza-centre fallback just in case.
                    error: (_, __) => _TruckListView(
                      trucks: _applyFilter(
                        trucks,
                        etaService,
                        LocationService.fallbackLat,
                        LocationService.fallbackLng,
                      ),
                      userLat: LocationService.fallbackLat,
                      userLng: LocationService.fallbackLng,
                      etaService: etaService,
                    ),
                  );
                },
                loading: () => const AquaShimmerList(),
                error: (e, _) => Center(
                  child: Text(
                    'خطأ: $e',
                    style: GoogleFonts.cairo(color: AppColors.danger),
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

// ── Truck list view ──────────────────────────────────────────────────────────

class _TruckListView extends StatelessWidget {
  final List<Truck> trucks;
  final double userLat;
  final double userLng;
  final EtaService etaService;

  const _TruckListView({
    required this.trucks,
    required this.userLat,
    required this.userLng,
    required this.etaService,
  });

  @override
  Widget build(BuildContext context) {
    if (trucks.isEmpty) return const _EmptyState();
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      itemCount: trucks.length,
      itemBuilder: (_, i) {
        final truck = trucks[i];
        final eta = etaService.calculateEta(
          truckLat: truck.latitude,
          truckLng: truck.longitude,
          userLat: userLat,
          userLng: userLng,
          averageSpeed: truck.averageSpeed,
        );
        return _TruckCard(
          truck: truck,
          eta: eta,
          etaService: etaService,
          onTap: () => context.push('/truck/${truck.id}'),
        )
            .animate(delay: Duration(milliseconds: 200 + i * 80))
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.08, end: 0);
      },
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.truck,
            size: 56.w,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          SizedBox(height: 12.h),
          Text(
            'لا توجد شاحنات',
            style: GoogleFonts.cairo(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Truck card ───────────────────────────────────────────────────────────────

class _TruckCard extends StatelessWidget {
  final Truck truck;
  final EtaResult eta;
  final EtaService etaService;
  final VoidCallback onTap;

  const _TruckCard({
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
            // ── Top row: icon | name + route | ETA ────────
            Row(
              children: [
                // Truck icon
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
                // Driver name + route
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
                // ETA badge
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
            // ── Bottom stats row ──────────────────────────
            Row(
              children: [
                _StatItem(
                  icon: Iconsax.location,
                  label: '${eta.distanceKm} كم',
                  color: AppColors.info,
                ),
                _Separator(),
                _StatItem(
                  icon: Iconsax.drop,
                  label: '${(truck.loadPercentage * 100).round()}% حمولة',
                  color: AppColors.primary,
                ),
                _Separator(),
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

class _Separator extends StatelessWidget {
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
