import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../parking/domain/repositories/parking_spot_repository.dart';
import '../../../trucks/domain/repositories/truck_repository.dart';
import '../../../../shared/services/location_service.dart';
import '../../domain/entities/driver_route.dart';
import '../../domain/repositories/driver_repository.dart';

/// Interval between position broadcasts while a trip is active.
/// Kept as a named constant so it's the single place to change for
/// testing (tests inject a much shorter duration — see the test file).
const kDriverLocationBroadcastInterval = Duration(minutes: 1);

/// A truck that has moved less than this since the previous broadcast is
/// considered stationary — i.e. parked rather than driving between
/// updates. Deliberately a bit tighter than [kParkingRadiusMeters] (the
/// radius used to *match* stops to the same cluster) since this only
/// needs to catch "didn't move," not "moved a little."
const double kParkingStationaryThresholdMeters = 40.0;

class DriverTripState {
  const DriverTripState({
    this.isActive = false,
    this.isPaused = false,
    this.currentRoute,
    this.lastBroadcastAt,
    this.lastLat,
    this.lastLng,
    this.isCurrentlyStopped = false,
    this.errorMessage,
  });

  final bool isActive;

  /// A paused trip keeps its route/timer suspended (the location
  /// broadcast loop stops) without releasing the assignment the way
  /// [endTrip] does — resuming picks the same route back up.
  final bool isPaused;
  final DriverRoute? currentRoute;
  final DateTime? lastBroadcastAt;
  final double? lastLat;
  final double? lastLng;

  /// True while the truck has been stationary since the last broadcast —
  /// used to count each stop at a location exactly once, rather than
  /// once per broadcast tick spent standing still.
  final bool isCurrentlyStopped;
  final String? errorMessage;

  DriverTripState copyWith({
    bool? isActive,
    bool? isPaused,
    DriverRoute? currentRoute,
    DateTime? lastBroadcastAt,
    double? lastLat,
    double? lastLng,
    bool? isCurrentlyStopped,
    String? errorMessage,
    bool clearError = false,
    bool clearRoute = false,
  }) {
    return DriverTripState(
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      currentRoute: clearRoute ? null : (currentRoute ?? this.currentRoute),
      lastBroadcastAt: lastBroadcastAt ?? this.lastBroadcastAt,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      isCurrentlyStopped: isCurrentlyStopped ?? this.isCurrentlyStopped,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

/// Drives the driver-side live-location broadcast: on [startTrip], it
/// immediately writes the truck's starting position to Firestore (via
/// [TruckRepository.startTrip], which creates the `trucks/{uid}` document
/// if needed), then re-reads the device GPS and re-writes the position
/// every [kDriverLocationBroadcastInterval] — by default every minute —
/// until [endTrip] is called.
///
/// Residents see these updates immediately because [TruckRepository]
/// writes to the exact same `trucks` collection that the resident-side
/// `trucksStreamProvider` already listens to — no separate sync layer.
class DriverLocationNotifier extends Notifier<DriverTripState> {
  Timer? _timer;
  StreamSubscription<({double lat, double lng})>? _positionSub;

  /// Most recent fix from the live background-capable stream. The
  /// broadcast timer reads this instead of taking a fresh one-shot GPS
  /// fix on every tick — cheaper on battery, and it's what the Android
  /// foreground service (tied to this same stream subscription) is
  /// already keeping current in the background.
  ({double lat, double lng})? _latestStreamPos;

  @override
  DriverTripState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _positionSub?.cancel();
    });
    return const DriverTripState();
  }

  TruckRepository get _truckRepo => GetIt.I<TruckRepository>();
  LocationService get _locationService => GetIt.I<LocationService>();

  Future<void> startTrip(DriverRoute route) async {
    if (state.isActive) return;

    final uid = GetIt.I<AuthRepository>().currentUser?.uid;
    if (uid == null) {
      state = state.copyWith(errorMessage: 'يجب تسجيل الدخول أولاً');
      return;
    }

    final pos = await _locationService.getCurrentPosition();

    final result = await _truckRepo.startTrip(
      truckId: uid,
      driverName:
          GetIt.I<AuthRepository>().currentUser?.displayName ?? 'سائق AquaPath',
      routeName: route.areaName,
      lat: pos.lat,
      lng: pos.lng,
      capacity: route.expectedLiters, // Use route's capacity
      activeRouteId: route.id, // Linked to specific trip
    );

    result.fold(
      (failure) => state = state.copyWith(errorMessage: failure.message),
      (_) async {
        state = state.copyWith(
          isActive: true,
          currentRoute: route,
          lastLat: pos.lat,
          lastLng: pos.lng,
          lastBroadcastAt: DateTime.now(),
          isCurrentlyStopped: false,
          clearError: true,
        );
        AppLogger.info(
          'Trip started for truck=$uid, route=${route.areaName}',
          tag: 'DriverLocation',
        );

        // Best-effort: without this permission the trip still works, it
        // just falls back to foreground-only broadcasting (same
        // behavior as before this fix) rather than failing outright —
        // a driver who denies "Allow all the time" shouldn't be blocked
        // from starting their trip over it.
        await _locationService.requestBackgroundPermission();

        _startBackgroundStream();
        _startTimer(uid);

        // Best-effort — a failure here shouldn't roll back the trip that
        // has already started broadcasting position.
        await GetIt.I<DriverRepository>().updateRouteStatus(
          routeId: route.id,
          status: 'in_progress',
        );
      },
    );
  }

  /// Subscribes to the foreground-service-backed position stream. The
  /// stream itself is what keeps the Android process alive in the
  /// background (via its persistent notification) — the periodic
  /// broadcast timer piggybacks on that, reading [_latestStreamPos]
  /// instead of taking its own GPS fix each tick.
  void _startBackgroundStream() {
    _positionSub?.cancel();
    _positionSub = _locationService.driverTripPositionStream.listen(
      (pos) => _latestStreamPos = pos,
      onError: (Object e) => AppLogger.warning(
        'Background position stream error: $e',
        tag: 'DriverLocation',
      ),
    );
  }

  void _startTimer(String truckId) {
    _timer?.cancel();
    _timer = Timer.periodic(kDriverLocationBroadcastInterval, (_) async {
      await _broadcastOnce(truckId);
    });
  }

  Future<void> _broadcastOnce(String truckId) async {
    final previousLat = state.lastLat;
    final previousLng = state.lastLng;

    // Prefer the position the live background stream already has — it's
    // free (no extra GPS round trip) and is exactly what's keeping the
    // foreground-service notification current. Only fall back to a
    // fresh one-shot fix if the stream hasn't emitted yet (e.g. the very
    // first tick right after startTrip, before the first stream event
    // arrives) or in tests, where the stream isn't running at all.
    final pos = _latestStreamPos ?? await _locationService.getCurrentPosition();
    final result = await _truckRepo.updateTruckLocation(
      truckId,
      pos.lat,
      pos.lng,
    );

    await result.fold(
      (failure) async {
        AppLogger.warning(
          'Location broadcast failed: ${failure.message}',
          tag: 'DriverLocation',
        );
        state = state.copyWith(errorMessage: failure.message);
      },
      (_) async {
        final movedMeters = (previousLat != null && previousLng != null)
            ? GeoUtils.distanceMeters(
                previousLat,
                previousLng,
                pos.lat,
                pos.lng,
              )
            : null;
        final nowStopped = movedMeters != null &&
            movedMeters <= kParkingStationaryThresholdMeters;

        // Only report the *transition* into stopped — not every tick
        // spent standing still — so a 10-minute stop counts once, not
        // once per broadcast interval.
        if (nowStopped && !state.isCurrentlyStopped) {
          await _reportParkingStop(pos.lat, pos.lng);
        }

        state = state.copyWith(
          lastLat: pos.lat,
          lastLng: pos.lng,
          lastBroadcastAt: DateTime.now(),
          isCurrentlyStopped: nowStopped,
          clearError: true,
        );
        AppLogger.info(
          'Location broadcast: truck=$truckId (${pos.lat}, ${pos.lng})',
          tag: 'DriverLocation',
        );
      },
    );
  }

  /// Best-effort — a failure to log a parking observation should never
  /// interrupt the location broadcast loop that residents depend on.
  Future<void> _reportParkingStop(double lat, double lng) async {
    final uid = GetIt.I<AuthRepository>().currentUser?.uid;
    if (uid == null) return;
    final result = await GetIt.I<ParkingSpotRepository>().registerStop(
      latitude: lat,
      longitude: lng,
      driverUid: uid,
      areaName: state.currentRoute?.areaName ?? '',
    );
    result.fold(
      (failure) => AppLogger.warning(
        'Parking stop report failed: ${failure.message}',
        tag: 'DriverLocation',
      ),
      (_) => AppLogger.info(
        'Parking stop reported at ($lat, $lng)',
        tag: 'DriverLocation',
      ),
    );
  }

  /// Exposed for testing — lets a test drive one broadcast tick
  /// synchronously without waiting for the real timer interval.
  Future<void> debugBroadcastNow() async {
    final uid = GetIt.I<AuthRepository>().currentUser?.uid;
    if (uid == null || !state.isActive) return;
    await _broadcastOnce(uid);
  }

  /// Pauses the broadcast loop without releasing the route — the
  /// difference from [endTrip], which clears the route and marks the
  /// route status completed.
  Future<void> pauseTrip() async {
    if (!state.isActive || state.isPaused) return;
    final uid = GetIt.I<AuthRepository>().currentUser?.uid;
    _timer?.cancel();
    _timer = null;
    _positionSub?.cancel();
    _positionSub = null;
    if (uid != null) {
      await _truckRepo.pauseTrip(uid);
    }
    AppLogger.info('Trip paused for truck=$uid', tag: 'DriverLocation');
    state = state.copyWith(isPaused: true);
  }

  Future<void> resumeTrip() async {
    if (!state.isActive || !state.isPaused) return;
    final uid = GetIt.I<AuthRepository>().currentUser?.uid;
    if (uid != null) {
      await _truckRepo.resumeTrip(uid);
      _startBackgroundStream();
      _startTimer(uid);
    }
    AppLogger.info('Trip resumed for truck=$uid', tag: 'DriverLocation');
    state = state.copyWith(isPaused: false);
  }

  Future<void> endTrip() async {
    if (!state.isActive) return;

    final uid = GetIt.I<AuthRepository>().currentUser?.uid;
    _timer?.cancel();
    _timer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _latestStreamPos = null;

    if (uid != null) {
      await _truckRepo.endTrip(uid);

      final route = state.currentRoute;
      if (route != null) {
        await GetIt.I<DriverRepository>().updateRouteStatus(
          routeId: route.id,
          status: 'completed',
        );
      }
    }

    AppLogger.info('Trip ended for truck=$uid', tag: 'DriverLocation');
    state = state.copyWith(
      isActive: false,
      isPaused: false,
      clearRoute: true,
      isCurrentlyStopped: false,
    );
  }
}

final driverLocationProvider =
    NotifierProvider<DriverLocationNotifier, DriverTripState>(
  DriverLocationNotifier.new,
);
