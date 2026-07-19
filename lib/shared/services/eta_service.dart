import 'dart:math';

import '../../features/trucks/domain/entities/eta_result.dart';

class EtaService {
  /// Computes distance + ETA using Haversine + time-based traffic factor.
  EtaResult calculateEta({
    required double truckLat,
    required double truckLng,
    required double userLat,
    required double userLng,
    required double averageSpeed,
  }) {
    final distance = _haversineKm(truckLat, truckLng, userLat, userLng);
    final trafficFactor = _trafficFactor();
    final safeSpeed = averageSpeed > 0 ? averageSpeed : 25.0;
    final etaMinutes =
        ((distance / safeSpeed) * 60 * trafficFactor).round().clamp(0, 999);

    return EtaResult(
      distanceKm: double.parse(distance.toStringAsFixed(1)),
      etaMinutes: etaMinutes,
      trafficFactor: trafficFactor,
      isNearby: distance <= 0.5,
    );
  }

  double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _rad(double deg) => deg * pi / 180;

  double _trafficFactor() {
    // Gaza = UTC+3; use fixed offset so device timezone doesn't affect estimates.
    final hour = DateTime.now().toUtc().add(const Duration(hours: 3)).hour;
    if (hour >= 6 && hour < 10) return 0.90;
    if (hour >= 10 && hour < 14) return 1.00;
    if (hour >= 14 && hour < 18) return 1.15;
    return 0.85;
  }

  /// Formats minutes to human-readable Arabic string.
  String formatEta(int minutes) {
    if (minutes <= 0) return 'وصلت!';
    if (minutes < 60) return '$minutes دقيقة';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours ساعة';
    return '$hours س و $mins د';
  }
}
