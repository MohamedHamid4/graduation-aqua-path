import 'package:flutter/material.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../core/widgets/aqua_app_bar.dart';
import '../../driver/domain/entities/driver_profile.dart';
import '../../driver/domain/entities/driver_route.dart';
import '../../parking/domain/entities/parking_spot.dart';
import '../../parking/domain/repositories/parking_spot_repository.dart';
import '../../parking/presentation/providers/parking_spot_providers.dart';
import '../../trucks/domain/entities/truck.dart';
import '../../trucks/presentation/providers/truck_providers.dart';
import 'providers/organization_providers.dart';

/// Four driver/truck status buckets the organization map distinguishes,
/// per spec: Active, Idle, Near Destination, Offline.
///
/// "Near destination" and "offline" aren't states the current [Truck]
/// entity tracks directly (it only has active/paused/idle from the
/// driver-side trip lifecycle) — this derives them: "near destination"
/// when an active truck is within 300m of its assigned route's end
/// point (`DriverRoute.endLat/endLng`, resolved via `activeRouteId`),
/// and "offline" when the last position update is older than twice the
/// broadcast interval (2 minutes), implying the driver app isn't
/// currently reporting.
enum _TruckStatusBucket { active, idle, nearDestination, offline }

class OrgLiveMonitoringScreen extends ConsumerWidget {
  const OrgLiveMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trucksAsync = ref.watch(trucksStreamProvider);
    final driversAsync = ref.watch(allDriversProvider);
    final allSpotsAsync = ref.watch(allParkingSpotsProvider);
    final routesAsync = ref.watch(allRoutesProvider);

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: const AquaAppBar(title: 'المراقبة الحية'),
      body: trucksAsync.when(
        data: (trucks) {
          final drivers = driversAsync.valueOrNull ?? [];
          final driverByUid = {for (final d in drivers) d.uid: d};
          final routeById = {
            for (final r in routesAsync.valueOrNull ?? <DriverRoute>[]) r.id: r,
          };

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(31.5018, 34.4668), // Gaza Strip centroid
                  zoom: 12,
                ),
                markers: {
                  ..._buildTruckMarkers(
                      context, trucks, driverByUid, routeById),
                  ..._buildParkingMarkers(
                      context, ref, allSpotsAsync.valueOrNull ?? []),
                },
              ),
              Positioned(
                top: 12.h,
                left: 12.w,
                right: 12.w,
                child: _LegendBar(),
              ),
              Positioned(
                bottom: 16.h,
                left: 16.w,
                right: 16.w,
                child: _ParkingManagementSheet(
                  spots: allSpotsAsync.valueOrNull ?? [],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('تعذّر تحميل بيانات الخريطة',
              style: GoogleFonts.cairo(color: AppColors.danger)),
        ),
      ),
    );
  }

  _TruckStatusBucket _bucketFor(
      Truck truck, Map<String, DriverRoute> routeById) {
    final isStale = DateTime.now().difference(truck.lastUpdated) >
        const Duration(minutes: 2);
    if (isStale) return _TruckStatusBucket.offline;
    if (!truck.isActive) return _TruckStatusBucket.idle;

    final routeId = truck.activeRouteId;
    final route = (routeId != null) ? routeById[routeId] : null;
    if (route != null) {
      final distanceToDestination = GeoUtils.distanceMeters(
        truck.latitude,
        truck.longitude,
        route.endLat,
        route.endLng,
      );
      if (distanceToDestination <= 300) {
        return _TruckStatusBucket.nearDestination;
      }
    }
    return _TruckStatusBucket.active;
  }

  Set<Marker> _buildTruckMarkers(
    BuildContext context,
    List<Truck> trucks,
    Map<String, DriverProfile> driverByUid,
    Map<String, DriverRoute> routeById,
  ) {
    return trucks.map((truck) {
      final bucket = _bucketFor(truck, routeById);
      final hue = switch (bucket) {
        _TruckStatusBucket.active => BitmapDescriptor.hueGreen,
        _TruckStatusBucket.nearDestination => BitmapDescriptor.hueYellow,
        _TruckStatusBucket.idle => BitmapDescriptor.hueOrange,
        _TruckStatusBucket.offline => BitmapDescriptor.hueAzure,
      };
      return Marker(
        markerId: MarkerId(truck.id),
        position: LatLng(truck.latitude, truck.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow:
            InfoWindow(title: truck.driverName, snippet: truck.routeName),
        onTap: () =>
            _showDriverDetail(context, truck, driverByUid[truck.id], bucket),
      );
    }).toSet();
  }

  Set<Marker> _buildParkingMarkers(
    BuildContext context,
    WidgetRef ref,
    List<ParkingSpot> spots,
  ) {
    return spots.map((spot) {
      return Marker(
        markerId: MarkerId('parking_${spot.id}'),
        position: LatLng(spot.latitude, spot.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: InfoWindow(
          title: 'موقف (${spot.approvalStatus.name})',
          snippet: '${spot.stopCount} توقفات — ${spot.areaName}',
        ),
        zIndex: 0.5,
      );
    }).toSet();
  }

  void _showDriverDetail(
    BuildContext context,
    Truck truck,
    DriverProfile? driver,
    _TruckStatusBucket bucket,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(driver?.fullName ?? truck.driverName,
                  style: GoogleFonts.cairo(
                      fontSize: 16.sp, fontWeight: FontWeight.w700)),
              if (driver != null)
                Text(driver.phone,
                    style: GoogleFonts.cairo(
                        fontSize: 12.sp, color: AppColors.textMuted)),
              SizedBox(height: 12.h),
              _kv('الحالة', _labelFor(bucket)),
              _kv(
                  'رقم لوحة الشاحنة',
                  driver?.truckPlateNumber.isNotEmpty == true
                      ? driver!.truckPlateNumber
                      : '—'),
              if (driver != null)
                _kv('المنطقة المكلّف بها', driver.assignedArea),
              _kv('السعة الكلية',
                  '${(driver?.truckCapacity ?? truck.capacity).toStringAsFixed(0)} لتر'),
              _kv('الكمية المتبقية',
                  '${truck.currentLoad.toStringAsFixed(0)} لتر'),
              _kv('الكمية الموزّعة',
                  '${truck.distributedAmount.toStringAsFixed(0)} لتر'),
              _kv('السرعة الحالية',
                  '${truck.averageSpeed.toStringAsFixed(0)} كم/س'),
              _kv('آخر تحديث', truck.lastUpdated.toArabicTimeAgo()),
              _kv('عدد التسليمات', '${truck.deliveryCount}'),
              _kv('ساعات العمل', _formatWorkingHours(truck.workingDuration)),
            ],
          ),
        ),
      ),
    );
  }

  String _labelFor(_TruckStatusBucket b) => switch (b) {
        _TruckStatusBucket.active => 'نشط',
        _TruckStatusBucket.nearDestination => 'قريب من الوجهة',
        _TruckStatusBucket.idle => 'خامل',
        _TruckStatusBucket.offline => 'غير متصل',
      };

  Widget _kv(String k, String v) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: GoogleFonts.cairo(
                    fontSize: 12.sp, color: AppColors.textMuted)),
            Text(v,
                style: GoogleFonts.cairo(
                    fontSize: 12.sp, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  String _formatWorkingHours(Duration? d) {
    if (d == null) return 'لا توجد رحلة نشطة';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours == 0) return '$minutes دقيقة';
    return '$hours س $minutes د';
  }
}

class _LegendBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _dot(AppColors.success, 'نشط'),
          _dot(AppColors.accent, 'قريب'),
          _dot(AppColors.warning, 'خامل'),
          _dot(AppColors.textMuted, 'غير متصل'),
        ],
      ),
    );
  }

  Widget _dot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          SizedBox(width: 4.w),
          Text(label, style: GoogleFonts.cairo(fontSize: 10.sp)),
        ],
      );
}

/// Organization moderation controls for auto-detected parking spots —
/// approve, edit area, disable, or delete.
class _ParkingManagementSheet extends StatelessWidget {
  final List<ParkingSpot> spots;

  const _ParkingManagementSheet({required this.spots});

  @override
  Widget build(BuildContext context) {
    final pending = spots
        .where((s) => s.approvalStatus == ParkingApprovalStatus.pending)
        .toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      constraints: BoxConstraints(maxHeight: 160.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('مواقف بانتظار الاعتماد (${pending.length})',
              style: GoogleFonts.cairo(
                  fontSize: 12.sp, fontWeight: FontWeight.w700)),
          SizedBox(height: 6.h),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: pending.length,
              itemBuilder: (_, i) {
                final spot = pending[i];
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${spot.areaName.isEmpty ? "—" : spot.areaName} · ${spot.stopCount} توقفات',
                        style: GoogleFonts.cairo(fontSize: 11.sp),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline,
                          color: Colors.green, size: 20),
                      onPressed: () => _runAndReport(
                        context,
                        () => GetIt.I<ParkingSpotRepository>()
                            .approveSpot(spot.id),
                      ),
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.block, color: AppColors.danger, size: 20),
                      onPressed: () => _runAndReport(
                        context,
                        () => GetIt.I<ParkingSpotRepository>()
                            .disableSpot(spot.id),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runAndReport(
    BuildContext context,
    Future<Either<Failure, Unit>> Function() action,
  ) async {
    final result = await action();
    if (!context.mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.danger,
        ),
      ),
      (_) {},
    );
  }
}
