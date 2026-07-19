import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:aquapath/features/parking/data/datasources/parking_spot_firebase_source.dart';
import 'package:aquapath/features/parking/data/models/parking_spot_dto.dart';
import 'package:aquapath/features/parking/data/repositories/parking_spot_repository_impl.dart';

class MockParkingSpotFirebaseSource extends Mock
    implements ParkingSpotFirebaseSource {}

void main() {
  late MockParkingSpotFirebaseSource source;
  late ParkingSpotRepositoryImpl repository;

  final sampleDto = ParkingSpotDto(
    id: 'spot_1',
    latitude: 31.5018,
    longitude: 34.4668,
    stopCount: 3,
    isVerified: true,
    lastStoppedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    source = MockParkingSpotFirebaseSource();
    repository = ParkingSpotRepositoryImpl(source);
  });

  group('watchVerifiedSpots', () {
    test('maps DTOs to domain entities wrapped in Right', () async {
      when(() => source.watchVerifiedSpots())
          .thenAnswer((_) => Stream.value([sampleDto]));

      final result = await repository.watchVerifiedSpots().first;

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('expected Right'),
        (spots) {
          expect(spots, hasLength(1));
          expect(spots.first.id, 'spot_1');
          expect(spots.first.isVerified, true);
          expect(spots.first.stopCount, 3);
        },
      );
    });

    test('emits Left when the underlying stream throws', () async {
      when(() => source.watchVerifiedSpots())
          .thenThrow(Exception('firestore down'));

      final result = await repository.watchVerifiedSpots().first;

      expect(result.isLeft(), true);
    });
  });

  group('registerStop', () {
    test('returns Right(unit) on success', () async {
      when(() => source.registerStop(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async {});

      final result = await repository.registerStop(
        latitude: 31.50,
        longitude: 34.46,
      );

      expect(result.isRight(), true);
      verify(() => source.registerStop(latitude: 31.50, longitude: 34.46))
          .called(1);
    });

    test('returns Left on failure without throwing', () async {
      when(() => source.registerStop(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenThrow(Exception('network error'));

      final result = await repository.registerStop(
        latitude: 31.50,
        longitude: 34.46,
      );

      expect(result.isLeft(), true);
    });
  });
}
