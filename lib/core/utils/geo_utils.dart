import 'dart:math';

/// Shared geospatial helpers. Kept dependency-free (no Firestore, no
/// Flutter) so it can be unit-tested in isolation and reused by any
/// feature that needs a great-circle distance — currently [EtaService]
/// and the truck-parking detection feature both need this calculation.
abstract final class GeoUtils {
  static const double _earthRadiusMeters = 6371000.0;

  /// Great-circle distance between two coordinates, in metres.
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _radians(lat2 - lat1);
    final dLng = _radians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_radians(lat1)) *
            cos(_radians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static double _radians(double degrees) => degrees * pi / 180;
}
