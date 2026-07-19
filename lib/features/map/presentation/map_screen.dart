import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/providers/notification_prefs_provider.dart';
import '../../parking/domain/entities/parking_spot.dart';
import '../../parking/presentation/providers/parking_spot_providers.dart';
import '../../trucks/domain/entities/truck.dart';
import '../../trucks/presentation/providers/truck_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  static const _gazaCenter = LatLng(31.5018, 34.4668);

  static const _lightMapStyle = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#b3d4f5"}]},
  {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f0f7ff"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e0ebf5"}]}
]
''';

  Set<Marker> _buildMarkers(List<Truck> trucks) {
    return trucks.map((truck) {
      return Marker(
        markerId: MarkerId(truck.id),
        position: LatLng(truck.latitude, truck.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          truck.isActive
              ? BitmapDescriptor.hueAzure
              : BitmapDescriptor.hueYellow,
        ),
        infoWindow: InfoWindow(
          title: truck.driverName,
          snippet: truck.routeName,
        ),
        onTap: () => _showTruckSheet(truck),
      );
    }).toSet();
  }

  Set<Marker> _buildParkingMarkers(List<ParkingSpot> spots) {
    return spots.map((spot) {
      return Marker(
        markerId: MarkerId('parking_${spot.id}'),
        position: LatLng(spot.latitude, spot.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        ),
        infoWindow: const InfoWindow(title: 'موقف شاحنات معتمد'),
        onTap: () => _showParkingDetailSheet(spot),
        zIndex: 0.5, // keep truck markers visually on top
      );
    }).toSet();
  }

  void _showParkingDetailSheet(ParkingSpot spot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParkingSpotDetailSheet(spot: spot),
    );
  }

  void _showTruckSheet(Truck truck) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickTruckSheet(truck: truck),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trucksAsync = ref.watch(trucksStreamProvider);
    final activeCount = ref.watch(activeTruckCountProvider);
    final notificationRadius =
        ref.watch(notificationPrefsProvider).radiusMeters;
    final parkingAsync = ref.watch(verifiedParkingSpotsProvider);
    // M-2: use the user's actual position for the notification radius circle.
    final userLocAsync = ref.watch(userLocationProvider);
    final circleCenter = userLocAsync.valueOrNull != null
        ? LatLng(userLocAsync.valueOrNull!.lat, userLocAsync.valueOrNull!.lng)
        : _gazaCenter;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _gazaCenter,
              zoom: 13,
            ),
            onMapCreated: (controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
            },
            markers: {
              ...trucksAsync.when(
                data: _buildMarkers,
                loading: () => <Marker>{},
                error: (_, __) => <Marker>{},
              ),
              ...parkingAsync.when(
                data: _buildParkingMarkers,
                loading: () => <Marker>{},
                error: (_, __) => <Marker>{},
              ),
            },
            circles: {
              Circle(
                circleId: const CircleId('userRadius'),
                center: circleCenter,
                radius: notificationRadius.toDouble(),
                fillColor: const Color(0x152196F3),
                strokeColor: const Color(0x402196F3),
                strokeWidth: 1,
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            style: _lightMapStyle,
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _MapHeader(activeCount: activeCount),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomCards(trucksAsync: trucksAsync),
          ),

          // M-3: tapping this button moves the camera to the user's location.
          Positioned(
            bottom: 165.h,
            right: 16.w,
            child: GestureDetector(
              onTap: () async {
                final loc = ref.read(userLocationProvider).valueOrNull;
                if (loc == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذّر تحديد موقعك')),
                  );
                  return;
                }
                final controller = await _mapController.future;
                await controller.animateCamera(
                  CameraUpdate.newLatLng(LatLng(loc.lat, loc.lng)),
                );
              },
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.borderDefault,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.my_location_rounded,
                  color: AppColors.primary,
                  size: 20.w,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  final int activeCount;

  const _MapHeader({
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgPrimary.withValues(alpha: 0.95),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16.w,
            8.h,
            16.w,
            12.h,
          ),
          child: Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  color: Colors.white,
                  size: 20.w,
                ),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.appName,
                    style: GoogleFonts.cairo(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'تتبع شاحنات المياه',
                    style: GoogleFonts.cairo(
                      fontSize: 11.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10.w,
                  vertical: 5.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      '$activeCount نشطة',
                      style: GoogleFonts.cairo(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms),
        ),
      ),
    );
  }
}

class _BottomCards extends StatelessWidget {
  final AsyncValue<List<Truck>> trucksAsync;

  const _BottomCards({
    required this.trucksAsync,
  });

  @override
  Widget build(BuildContext context) {
    return trucksAsync.when(
      data: (trucks) {
        if (trucks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: EdgeInsets.only(top: 12.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppColors.bgPrimary,
                AppColors.bgPrimary.withValues(alpha: 0.9),
                Colors.transparent,
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 150.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                ),
                itemCount: trucks.length,
                itemBuilder: (_, index) {
                  return _TruckMiniCard(
                    truck: trucks[index],
                  )
                      .animate(
                        delay: Duration(
                          milliseconds: 200 + index * 100,
                        ),
                      )
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: 0.2, end: 0);
                },
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TruckMiniCard extends StatelessWidget {
  final Truck truck;

  const _TruckMiniCard({
    required this.truck,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push(
          RouteNames.truckDetailOf(truck.id),
        );
      },
      child: Container(
        width: 230.w,
        margin: EdgeInsets.only(left: 10.w),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.borderDefault,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    color:
                        (truck.isActive ? AppColors.primary : AppColors.accent)
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_shipping_rounded,
                    color:
                        truck.isActive ? AppColors.primary : AppColors.accent,
                    size: 18.w,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        truck.driverName,
                        style: GoogleFonts.cairo(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        truck.routeName,
                        style: GoogleFonts.cairo(
                          fontSize: 10.sp,
                          color: AppColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.speed_rounded,
                  label: '${truck.averageSpeed.round()} كم/س',
                ),
                SizedBox(width: 6.w),
                _InfoChip(
                  icon: Icons.water_drop_outlined,
                  label:
                      '${(truck.currentLoad / 1000).toStringAsFixed(0)}K لتر',
                ),
              ],
            ),
            SizedBox(height: 6.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: truck.loadPercentage,
                backgroundColor: AppColors.borderDefault,
                valueColor: AlwaysStoppedAnimation<Color>(
                  truck.loadPercentage > 0.5
                      ? AppColors.primary
                      : AppColors.warning,
                ),
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6.w,
        vertical: 3.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12.w,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: 3.w),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 9.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTruckSheet extends StatelessWidget {
  final Truck truck;

  const _QuickTruckSheet({
    required this.truck,
  });

  @override
  Widget build(BuildContext context) {
    final bool showDeliveryButton = truck.status == 'active' &&
        truck.activeRouteId?.trim().isNotEmpty == true &&
        truck.currentLoad > 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20.w,
        12.h,
        20.w,
        28.h,
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
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  gradient: truck.isActive ? AppColors.primaryGradient : null,
                  color: truck.isActive
                      ? null
                      : AppColors.textMuted.withValues(
                          alpha: 0.1,
                        ),
                  borderRadius: BorderRadius.circular(14),
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
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      truck.routeName,
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8.w,
                  vertical: 4.h,
                ),
                decoration: BoxDecoration(
                  color:
                      (truck.isActive ? AppColors.success : AppColors.warning)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  truck.isActive ? AppStrings.active : AppStrings.idle,
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color:
                        truck.isActive ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);

                context.push(
                  RouteNames.truckDetailOf(truck.id),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'عرض التفاصيل',
                style: GoogleFonts.cairo(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (showDeliveryButton) ...[
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);

                  context.push(
                    RouteNames.waterDeliveryOf(truck.id),
                  );
                },
                icon: Icon(
                  Icons.water_drop_rounded,
                  size: 20.w,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                label: Text(
                  'سجل استلام المياه',
                  style: GoogleFonts.cairo(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
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

/// Detail sheet shown when a resident taps an approved parking marker —
/// per spec: location, assigned area, stop count, associated driver(s),
/// and last-detected time.
class _ParkingSpotDetailSheet extends StatelessWidget {
  final ParkingSpot spot;

  const _ParkingSpotDetailSheet({required this.spot});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.all(12.w),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.local_parking_rounded,
                      color: AppColors.accent, size: 22.w),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'موقف شاحنات معتمد',
                    style: GoogleFonts.cairo(
                        fontSize: 16.sp, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _row('المنطقة', spot.areaName.isEmpty ? '—' : spot.areaName),
            _row('عدد مرات التوقف', '${spot.stopCount}'),
            _row('عدد السائقين', '${spot.driverUids.length}'),
            _row('آخر توقف مسجّل', spot.lastStoppedAt.toArabicTimeAgo()),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 13.sp, color: AppColors.textMuted)),
            Text(value,
                style: GoogleFonts.cairo(
                    fontSize: 13.sp, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
