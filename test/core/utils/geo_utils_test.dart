import 'package:flutter_test/flutter_test.dart';

import 'package:aquapath/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils.distanceMeters', () {
    test('returns ~0 for identical coordinates', () {
      final d = GeoUtils.distanceMeters(31.5018, 34.4668, 31.5018, 34.4668);
      expect(d, closeTo(0, 0.001));
    });

    test('matches a known short distance within Gaza City', () {
      // ~5.85m apart — verified against an independent Haversine
      // calculation; used as the "barely moved" fixture in the driver
      // location provider tests too.
      final d = GeoUtils.distanceMeters(
        31.501,
        34.461,
        31.50104,
        34.46104,
      );
      expect(d, closeTo(5.85, 0.5));
    });

    test('matches a known ~1.3km distance', () {
      final d = GeoUtils.distanceMeters(
        31.50104,
        34.46104,
        31.510,
        34.470,
      );
      expect(d, closeTo(1309, 5));
    });

    test('is symmetric', () {
      final a = GeoUtils.distanceMeters(31.50, 34.46, 31.52, 34.48);
      final b = GeoUtils.distanceMeters(31.52, 34.48, 31.50, 34.46);
      expect(a, closeTo(b, 0.0001));
    });

    test('distance grows with coordinate separation', () {
      final near = GeoUtils.distanceMeters(31.50, 34.46, 31.5001, 34.46);
      final far = GeoUtils.distanceMeters(31.50, 34.46, 31.55, 34.46);
      expect(far, greaterThan(near));
    });
  });
}
