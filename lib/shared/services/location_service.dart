import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Why an explicit, user-triggered location request ([LocationService.
/// requestCurrentFix]) could not return a real device fix.
enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

/// Result of an explicit "locate me" request. Unlike [LocationService.
/// getCurrentPosition] (which silently substitutes the Gaza fallback so
/// background calculations like ETA keep working), this never hides a
/// failure — the caller needs to know precisely why a fix couldn't be
/// obtained so it can prompt the user correctly instead of the map
/// silently doing nothing.
class LocationFix {
  final double? lat;
  final double? lng;
  final LocationFailure? failure;

  const LocationFix.success(double latitude, double longitude)
      : lat = latitude,
        lng = longitude,
        failure = null;

  const LocationFix.failed(LocationFailure reason)
      : lat = null,
        lng = null,
        failure = reason;

  bool get isSuccess => failure == null;
}

/// Wraps the device geolocation APIs with permission handling.
///
/// Falls back to Gaza City's centre coordinates whenever location
/// services are unavailable, permission is denied, or an error occurs —
/// this keeps ETA calculations functional even without GPS access.
class LocationService {
  static const double fallbackLat = 31.5018;
  static const double fallbackLng = 34.4668;

  /// Returns the current device position, requesting permission if needed.
  /// Returns the Gaza-centre fallback coordinates on any failure.
  Future<({double lat, double lng})> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (lat: fallbackLat, lng: fallbackLng);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (lat: fallbackLat, lng: fallbackLng);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return (lat: position.latitude, lng: position.longitude);
    } on Exception {
      return (lat: fallbackLat, lng: fallbackLng);
    }
  }

  /// Requests one fresh device fix for an explicit user action (e.g. the
  /// map's "my location" button). Always takes a live GPS reading —
  /// never a cached/stale value — and reports the precise reason on
  /// failure instead of substituting the Gaza fallback, so the caller can
  /// show the user something actionable (enable GPS / grant permission)
  /// rather than the map appearing to just do nothing.
  Future<LocationFix> requestCurrentFix() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationFix.failed(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const LocationFix.failed(LocationFailure.permissionDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationFix.failed(LocationFailure.permissionDeniedForever);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationFix.success(position.latitude, position.longitude);
    } on Exception {
      return const LocationFix.failed(LocationFailure.unavailable);
    }
  }

  /// Live stream of position updates (e.g. for moving the map camera).
  /// Emits nothing if permission is unavailable. Foreground-only — use
  /// [driverTripPositionStream] for the driver's active-trip broadcast,
  /// which is backed by an Android foreground service so it survives the
  /// app being backgrounded.
  Stream<({double lat, double lng})> get positionStream {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).map((p) => (lat: p.latitude, lng: p.longitude));
  }

  /// Requests the extra permission a background-capable location stream
  /// needs on Android 10+ (`ACCESS_BACKGROUND_LOCATION`). Must be
  /// requested *after* fine/coarse location has already been granted —
  /// the OS permission dialog for it doesn't appear otherwise. Call this
  /// once, right before starting a trip; safe to call repeatedly (it's a
  /// no-op if already granted).
  Future<bool> requestBackgroundPermission() async {
    final current = await Geolocator.checkPermission();
    if (current == LocationPermission.deniedForever) return false;
    if (current == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        return false;
      }
    }
    // `LocationPermission.always` is the background-capable grant on
    // Android/iOS; `whileInUse` only works in the foreground. Geolocator
    // triggers the second-step "Allow all the time" system dialog only
    // when this is called after the initial while-in-use grant exists.
    final result = await Geolocator.requestPermission();
    return result == LocationPermission.always ||
        result == LocationPermission.whileInUse;
  }

  /// Position stream for an **active driver trip**. On Android this runs
  /// inside a foreground service (persistent notification, per Android's
  /// own requirement for any app that tracks location with the screen
  /// off) so broadcasting continues if the driver locks their screen or
  /// switches to another app mid-delivery — the gap the previous
  /// `Timer.periodic` + one-shot-`getCurrentPosition()` polling loop had,
  /// since polling silently stops the moment the app leaves the
  /// foreground.
  ///
  /// Requires `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, and
  /// `FOREGROUND_SERVICE_LOCATION` in AndroidManifest.xml (already added)
  /// — without them the stream still works, just foreground-only, same
  /// as before.
  Stream<({double lat, double lng})> get driverTripPositionStream {
    return Geolocator.getPositionStream(
      locationSettings: _driverTripLocationSettings(),
    ).map((p) => (lat: p.latitude, lng: p.longitude));
  }

  LocationSettings _driverTripLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        intervalDuration: const Duration(seconds: 20),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'رحلة توزيع نشطة',
          notificationText: 'يشارك AquaPath موقع الشاحنة أثناء الرحلة',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    // Non-Android platforms (no iOS target currently ships in this
    // project — see README) fall back to the plain, foreground-only
    // stream. If iOS is added later this needs an AppleSettings branch
    // with allowBackgroundLocationUpdates + the UIBackgroundModes
    // "location" entry in Info.plist; deliberately not stubbed here
    // since an untested guess at that config is worse than an honest gap.
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );
  }
}
