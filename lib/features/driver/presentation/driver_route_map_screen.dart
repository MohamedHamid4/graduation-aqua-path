import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get_it/get_it.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/extensions.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/entities/driver_route.dart';
import 'providers/driver_delivery_provider.dart';
import 'providers/driver_location_provider.dart';
import 'providers/driver_routes_provider.dart';

/// Live route map for a driver's active (or about-to-start) delivery.
///
/// Draws a straight line from the trip's start point to the destination
/// area's centroid — intentionally the same Haversine-style straight-line
/// approach the resident side already uses for ETA, rather than a routed
/// polyline from the Directions API, which is out of scope (see the
/// project proposal's "Out of Scope" section on route optimization).
///
/// Once the driver taps "بدء الرحلة", [DriverLocationNotifier] captures
/// the GPS position, writes it to `trucks/{uid}` in Firestore, and then
/// re-broadcasts every minute — the same document the resident-side
/// `trucksStreamProvider` is already listening to, so the new position
/// appears on the resident's map without any extra plumbing.
class DriverRouteMapScreen extends ConsumerStatefulWidget {
  final String routeId;

  const DriverRouteMapScreen({super.key, required this.routeId});

  @override
  ConsumerState<DriverRouteMapScreen> createState() =>
      _DriverRouteMapScreenState();
}

class _DriverRouteMapScreenState extends ConsumerState<DriverRouteMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  Timer? _tickerForDisplay;

  @override
  void initState() {
    super.initState();
    // Repaints the "آخر تحديث منذ..." label every 10s — purely cosmetic,
    // independent of the real 60s broadcast timer in the notifier.
    _tickerForDisplay = Timer.periodic(
      const Duration(seconds: 10),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _tickerForDisplay?.cancel();
    super.dispose();
  }

  DriverRoute? _findRoute(List<DriverRoute> routes) {
    for (final r in routes) {
      if (r.id == widget.routeId) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(driverRoutesProvider).valueOrNull ?? [];
    final route = _findRoute(routes);
    final tripState = ref.watch(driverLocationProvider);

    if (route == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final startLatLng = LatLng(route.startLat, route.startLng);
    final endLatLng = LatLng(route.endLat, route.endLng);
    final driverLatLng =
        (tripState.lastLat != null && tripState.lastLng != null)
            ? LatLng(tripState.lastLat!, tripState.lastLng!)
            : startLatLng;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: startLatLng,
              zoom: 12.5,
            ),
            onMapCreated: (c) {
              if (!_mapController.isCompleted) _mapController.complete(c);
            },
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: [startLatLng, endLatLng],
                color: AppColors.primary,
                width: 4,
                patterns: [PatternItem.dash(16), PatternItem.gap(10)],
              ),
            },
            markers: {
              Marker(
                markerId: const MarkerId('start'),
                position: startLatLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
                infoWindow: const InfoWindow(title: 'نقطة البدء'),
              ),
              Marker(
                markerId: const MarkerId('end'),
                position: endLatLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
                infoWindow: InfoWindow(title: 'الوجهة: ${route.areaName}'),
              ),
              if (tripState.isActive)
                Marker(
                  markerId: const MarkerId('driver'),
                  position: driverLatLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure,
                  ),
                  infoWindow: const InfoWindow(title: 'موقعك الحالي'),
                ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // ── Back button ──────────────────────────────────────────────
          Positioned(
            top: 44.h,
            right: 14.w,
            child: GestureDetector(
              onTap: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.borderDefault),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16.w,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),

          // ── Bottom control sheet ─────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 28.h),
              decoration: const BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 16),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.flag_rounded,
                        size: 18.w,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'الوجهة: ${route.areaName}',
                          style: GoogleFonts.cairo(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (tripState.isActive)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
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
                              SizedBox(width: 4.w),
                              Text(
                                AppStrings.active,
                                style: GoogleFonts.cairo(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14.w,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        tripState.isActive
                            ? 'آخر تحديث موقع: ${tripState.lastBroadcastAt?.toArabicTimeAgo() ?? 'لم يبدأ بعد'}'
                            : 'اضغط "بدء الرحلة" لبدء مشاركة موقعك',
                        style: GoogleFonts.cairo(
                          fontSize: 11.sp,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (tripState.errorMessage != null) ...[
                    SizedBox(height: 8.h),
                    Text(
                      tripState.errorMessage!,
                      style: GoogleFonts.cairo(
                        fontSize: 11.sp,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final notifier =
                            ref.read(driverLocationProvider.notifier);
                        if (tripState.isActive) {
                          await notifier.endTrip();
                          if (context.mounted) context.pop();
                        } else {
                          await notifier.startTrip(route);
                        }
                      },
                      icon: Icon(
                        tripState.isActive
                            ? Icons.stop_circle_outlined
                            : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                      label: Text(
                        tripState.isActive ? 'إنهاء الرحلة' : 'بدء الرحلة',
                        style: GoogleFonts.cairo(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tripState.isActive
                            ? AppColors.danger
                            : AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  if (tripState.isActive) ...[
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final notifier =
                                  ref.read(driverLocationProvider.notifier);
                              if (tripState.isPaused) {
                                await notifier.resumeTrip();
                              } else {
                                await notifier.pauseTrip();
                              }
                            },
                            icon: Icon(
                              tripState.isPaused
                                  ? Icons.play_circle_outline
                                  : Icons.pause_circle_outline,
                              size: 18,
                            ),
                            label: Text(
                              tripState.isPaused
                                  ? AppStrings.resumeTrip
                                  : AppStrings.pauseTrip,
                              style: GoogleFonts.cairo(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: tripState.isPaused
                                ? null
                                : () => _showConfirmDeliverySheet(
                                      context,
                                      ref,
                                      route,
                                    ),
                            icon: const Icon(Icons.local_shipping_outlined,
                                size: 18),
                            label: Text(
                              AppStrings.confirmDelivery,
                              style: GoogleFonts.cairo(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.15, end: 0),
        ],
      ),
    );
  }

  // Maximum delivery amount in litres per single confirmation (roughly the
  // largest truck capacity expected in this deployment).
  static const double _maxDeliveryLiters = 15000.0;

  void _showConfirmDeliverySheet(
    BuildContext context,
    WidgetRef ref,
    DriverRoute route,
  ) {
    final amountCtrl = TextEditingController();
    final truckId = GetIt.I<AuthRepository>().currentUser?.uid;
    if (truckId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20.h,
          ),
          child: Consumer(
            builder: (context, sheetRef, _) {
              final state = sheetRef.watch(driverDeliveryConfirmProvider);

              sheetRef.listen(driverDeliveryConfirmProvider, (prev, next) {
                if (next.success) {
                  Navigator.of(sheetContext).pop();
                  sheetRef.read(driverDeliveryConfirmProvider.notifier).reset();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تأكيد التسليم بنجاح')),
                  );
                }
              });

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تأكيد كمية المياه المسلّمة',
                    style: GoogleFonts.cairo(
                        fontSize: 16.sp, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'المنطقة: ${route.areaName}',
                    style: GoogleFonts.cairo(
                        fontSize: 12.sp, color: AppColors.textMuted),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'الكمية (لتر)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (state.error != null) ...[
                    SizedBox(height: 8.h),
                    Text(state.error!,
                        style: GoogleFonts.cairo(
                            fontSize: 12.sp, color: AppColors.danger)),
                  ],
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: state.isSubmitting
                          ? null
                          : () {
                              final amount =
                                  double.tryParse(amountCtrl.text.trim());
                              if (amount == null ||
                                  amount <= 0 ||
                                  amount > _maxDeliveryLiters) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'الكمية يجب أن تكون بين 1 و${_maxDeliveryLiters.toStringAsFixed(0)} لتر',
                                      style: GoogleFonts.cairo(),
                                    ),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                                return;
                              }
                              sheetRef
                                  .read(driverDeliveryConfirmProvider.notifier)
                                  .confirm(
                                    amountLiters: amount,
                                    truckId: truckId,
                                    areaName: route.areaName,
                                  );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(AppStrings.confirm,
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
