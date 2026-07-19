import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_names.dart';
import '../../../shared/services/eta_service.dart';
import '../../../shared/services/location_service.dart';
import '../../trucks/domain/entities/eta_result.dart';
import '../../trucks/domain/entities/truck.dart';
import '../../trucks/presentation/providers/truck_providers.dart';

class TruckDetailScreen extends ConsumerWidget {
  final String truckId;

  const TruckDetailScreen({
    super.key,
    required this.truckId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trucksAsync = ref.watch(trucksStreamProvider);
    final etaService = ref.watch(etaServiceProvider);
    final userLocationAsync = ref.watch(userLocationProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: trucksAsync.when(
        data: (trucks) {
          final truck = trucks.firstWhere(
            (t) => t.id == truckId,
            orElse: () => trucks.isNotEmpty ? trucks.first : _placeholder(),
          );

          final userPos = userLocationAsync.valueOrNull ??
              (
                lat: LocationService.fallbackLat,
                lng: LocationService.fallbackLng,
              );

          final eta = etaService.calculateEta(
            truckLat: truck.latitude,
            truckLng: truck.longitude,
            userLat: userPos.lat,
            userLng: userPos.lng,
            averageSpeed: truck.averageSpeed,
          );

          return _DetailBody(
            truck: truck,
            eta: eta,
            etaService: etaService,
            userLat: userPos.lat,
            userLng: userPos.lng,
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
        error: (error, _) => Center(
          child: Text(
            'خطأ: $error',
            style: GoogleFonts.cairo(color: AppColors.danger),
          ),
        ),
      ),
    );
  }

  Truck _placeholder() {
    return Truck(
      id: '',
      driverName: 'غير معروف',
      latitude: LocationService.fallbackLat,
      longitude: LocationService.fallbackLng,
      lastUpdated: DateTime.now(),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Truck truck;
  final EtaResult eta;
  final EtaService etaService;
  final double userLat;
  final double userLng;

  const _DetailBody({
    required this.truck,
    required this.eta,
    required this.etaService,
    required this.userLat,
    required this.userLng,
  });

  @override
  Widget build(BuildContext context) {
    final isClose = eta.etaMinutes < 15;
    final cardColor = isClose ? AppColors.success : AppColors.primary;

    final canRegisterWater = truck.status == 'active' &&
        truck.activeRouteId?.trim().isNotEmpty == true &&
        truck.currentLoad > 0;

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    truck.latitude,
                    truck.longitude,
                  ),
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('truck'),
                    position: LatLng(
                      truck.latitude,
                      truck.longitude,
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    ),
                    infoWindow: InfoWindow(
                      title: truck.driverName,
                    ),
                  ),
                  Marker(
                    markerId: const MarkerId('user'),
                    position: LatLng(
                      userLat,
                      userLng,
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                  ),
                },
                zoomControlsEnabled: false,
                myLocationEnabled: false,
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.borderDefault,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 16.w,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20.w,
                16.h,
                20.w,
                32.h,
              ),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderDefault,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Container(
                      width: 52.w,
                      height: 52.w,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.local_shipping_rounded,
                        color: Colors.white,
                        size: 26.w,
                      ),
                    ).animate().scale(
                          duration: 500.ms,
                          curve: Curves.elasticOut,
                        ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            truck.driverName,
                            style: GoogleFonts.cairo(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            truck.routeName,
                            style: GoogleFonts.cairo(
                              fontSize: 13.sp,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: (truck.isActive
                                ? AppColors.success
                                : AppColors.warning)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: truck.isActive
                                  ? AppColors.success
                                  : AppColors.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            truck.isActive
                                ? AppStrings.active
                                : AppStrings.idle,
                            style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: truck.isActive
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
                    .animate(
                      delay: 100.ms,
                    )
                    .fadeIn(
                      duration: 400.ms,
                    ),
                SizedBox(height: 20.h),
                Container(
                  padding: EdgeInsets.all(18.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cardColor,
                        cardColor.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: cardColor.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            etaService.formatEta(
                              eta.etaMinutes,
                            ),
                            style: GoogleFonts.cairo(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'وقت الوصول المتوقع',
                            style: GoogleFonts.cairo(
                              fontSize: 11.sp,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 44,
                        color: Colors.white24,
                      ),
                      Column(
                        children: [
                          Text(
                            '${eta.distanceKm} كم',
                            style: GoogleFonts.cairo(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'المسافة الباقية',
                            style: GoogleFonts.cairo(
                              fontSize: 11.sp,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
                    .animate(
                      delay: 200.ms,
                    )
                    .fadeIn(
                      duration: 400.ms,
                    ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Iconsax.drop,
                        label: 'الحمولة',
                        value:
                            '${NumberFormat('#,###').format(truck.currentLoad)} لتر',
                        percent: truck.loadPercentage,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.speed_rounded,
                        label: 'السرعة',
                        value: '${truck.averageSpeed.round()} كم/س',
                        color: AppColors.info,
                      ),
                    ),
                  ],
                )
                    .animate(
                      delay: 300.ms,
                    )
                    .fadeIn(
                      duration: 400.ms,
                    ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Iconsax.clock,
                        label: 'آخر تحديث',
                        value: _timeSince(
                          truck.lastUpdated,
                        ),
                        color: AppColors.accent,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.traffic_rounded,
                        label: 'حالة الطريق',
                        value: _trafficLabel(
                          eta.trafficFactor,
                        ),
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                )
                    .animate(
                      delay: 400.ms,
                    )
                    .fadeIn(
                      duration: 400.ms,
                    ),
                SizedBox(height: 20.h),
                if (canRegisterWater) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 54.h,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push(
                          RouteNames.waterDeliveryOf(
                            truck.id,
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.water_drop_rounded,
                        size: 21,
                      ),
                      label: Text(
                        'تسجيل استلام المياه',
                        style: GoogleFonts.cairo(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  )
                      .animate(
                        delay: 500.ms,
                      )
                      .fadeIn(
                        duration: 400.ms,
                      ),
                  SizedBox(height: 12.h),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _timeSince(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inMinutes < 1) {
      return 'الآن';
    }

    if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    }

    return 'منذ ${difference.inHours} ساعة';
  }

  String _trafficLabel(double factor) {
    if (factor < 0.95) {
      return 'خفيفة';
    }

    if (factor < 1.1) {
      return 'متوسطة';
    }

    return 'كثيفة';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double? percent;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18.w,
                color: color,
              ),
              const Spacer(),
              if (percent != null)
                Text(
                  '${(percent! * 100).round()}%',
                  style: GoogleFonts.cairo(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 10.sp,
              color: AppColors.textMuted,
            ),
          ),
          if (percent != null) ...[
            SizedBox(height: 8.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: color.withValues(
                  alpha: 0.1,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  color,
                ),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
