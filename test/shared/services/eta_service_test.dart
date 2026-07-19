import 'package:flutter_test/flutter_test.dart';
import 'package:aquapath/shared/services/eta_service.dart';

void main() {
  late EtaService etaService;

  setUp(() {
    etaService = EtaService();
  });

  group('EtaService — calculateEta', () {
    const gazaCenterLat = 31.5018;
    const gazaCenterLng = 34.4668;

    test('calculates correct distance and ETA for known coordinates', () {
      // Approx 1.1km away
      final result = etaService.calculateEta(
        truckLat: 31.5098,
        truckLng: 34.4621,
        userLat: gazaCenterLat,
        userLng: gazaCenterLng,
        averageSpeed: 25.0,
      );

      expect(result.distanceKm, closeTo(1.1, 0.1));
      expect(result.etaMinutes, isPositive);
    });

    test('handles same origin and destination (zero distance)', () {
      final result = etaService.calculateEta(
        truckLat: gazaCenterLat,
        truckLng: gazaCenterLng,
        userLat: gazaCenterLat,
        userLng: gazaCenterLng,
        averageSpeed: 25.0,
      );

      expect(result.distanceKm, 0.0);
      expect(result.etaMinutes, 0);
      expect(result.isNearby, true);
    });

    test('uses safe default speed when averageSpeed is 0 or negative', () {
      final resultZero = etaService.calculateEta(
        truckLat: 31.5098,
        truckLng: 34.4621,
        userLat: gazaCenterLat,
        userLng: gazaCenterLng,
        averageSpeed: 0,
      );

      final resultNegative = etaService.calculateEta(
        truckLat: 31.5098,
        truckLng: 34.4621,
        userLat: gazaCenterLat,
        userLng: gazaCenterLng,
        averageSpeed: -10,
      );

      expect(resultZero.etaMinutes, isPositive);
      expect(resultNegative.etaMinutes, isPositive);
      expect(resultZero.etaMinutes, equals(resultNegative.etaMinutes));
    });

    test('handles reasonable coordinate changes', () {
      // Move truck 100m north
      final start = etaService.calculateEta(
        truckLat: 31.5018,
        truckLng: 34.4668,
        userLat: 31.5050,
        userLng: 34.4668,
        averageSpeed: 25.0,
      );

      final moved = etaService.calculateEta(
        truckLat: 31.5019,
        truckLng: 34.4668,
        userLat: 31.5050,
        userLng: 34.4668,
        averageSpeed: 25.0,
      );

      expect(moved.distanceKm, lessThan(start.distanceKm));
      expect(moved.etaMinutes, lessThanOrEqualTo(start.etaMinutes));
    });

    test('marks isNearby correctly based on 0.5km threshold', () {
      final close = etaService.calculateEta(
        truckLat: 31.5019,
        truckLng: 34.4669,
        userLat: gazaCenterLat,
        userLng: gazaCenterLng,
        averageSpeed: 25.0,
      );
      final far = etaService.calculateEta(
        truckLat: 31.5500,
        truckLng: 34.5000,
        userLat: gazaCenterLat,
        userLng: gazaCenterLng,
        averageSpeed: 25.0,
      );

      expect(close.isNearby, true);
      expect(far.isNearby, false);
    });
  });

  group('EtaService — formatEta', () {
    test('returns "وصلت!" for 0 or negative minutes', () {
      expect(etaService.formatEta(0), 'وصلت!');
      expect(etaService.formatEta(-5), 'وصلت!');
    });

    test('formats minutes correctly (< 60)', () {
      expect(etaService.formatEta(1), '1 دقيقة');
      expect(etaService.formatEta(45), '45 دقيقة');
    });

    test('formats hours correctly (multiple of 60)', () {
      expect(etaService.formatEta(60), '1 ساعة');
      expect(etaService.formatEta(120), '2 ساعة');
    });

    test('formats combined hours and minutes correctly', () {
      expect(etaService.formatEta(65), '1 س و 5 د');
      expect(etaService.formatEta(150), '2 س و 30 د');
    });
  });
}
