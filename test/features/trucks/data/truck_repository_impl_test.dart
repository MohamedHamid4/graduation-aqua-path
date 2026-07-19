import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:aquapath/core/network/connectivity_service.dart';
import 'package:aquapath/features/trucks/data/datasources/truck_firebase_source.dart';
import 'package:aquapath/features/trucks/data/datasources/truck_local_source.dart';
import 'package:aquapath/features/trucks/data/models/truck_dto.dart';
import 'package:aquapath/features/trucks/data/repositories/truck_repository_impl.dart';

class MockTruckFirebaseSource extends Mock implements TruckFirebaseSource {}

class MockTruckLocalSource extends Mock implements TruckLocalSource {}

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Map<String, dynamic>>[]);
  });

  late MockTruckFirebaseSource firebaseSource;
  late MockTruckLocalSource localSource;
  late MockConnectivityService connectivityService;
  late TruckRepositoryImpl repository;

  final sampleDto = TruckDto(
    id: 'truck_1',
    driverName: 'أحمد محمد',
    latitude: 31.5098,
    longitude: 34.4621,
    averageSpeed: 25.0,
    status: 'active',
    capacity: 10000,
    currentLoad: 8000,
    lastUpdated: DateTime(2026, 1, 1),
    routeName: 'الشجاعية - الزيتون',
  );

  setUp(() {
    firebaseSource = MockTruckFirebaseSource();
    localSource = MockTruckLocalSource();
    connectivityService = MockConnectivityService();
    repository = TruckRepositoryImpl(
      firebaseSource: firebaseSource,
      localSource: localSource,
      connectivityService: connectivityService,
    );

    // Default stub for cache writes triggered as a side-effect while online.
    when(() => localSource.cacheTrucks(any())).thenAnswer((_) async {});
    when(() => localSource.updateCacheTime()).thenAnswer((_) async {});
  });

  group('TruckRepositoryImpl.getTrucksStream', () {
    test('streams trucks from Firebase when connected', () async {
      when(() => connectivityService.isConnected).thenAnswer((_) async => true);
      when(() => firebaseSource.getTrucksStream())
          .thenAnswer((_) => Stream.value([sampleDto]));

      final result = await repository.getTrucksStream().first;

      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('expected Right, got Left($failure)'),
        (trucks) {
          expect(trucks, hasLength(1));
          expect(trucks.first.id, 'truck_1');
          expect(trucks.first.driverName, 'أحمد محمد');
        },
      );
      verify(() => localSource.cacheTrucks(any())).called(1);
    });

    test('falls back to local cache when offline', () async {
      when(() => connectivityService.isConnected)
          .thenAnswer((_) async => false);
      when(() => localSource.getCachedTrucks()).thenReturn([sampleDto.toMap()]);

      final result = await repository.getTrucksStream().first;

      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('expected Right, got Left($failure)'),
        (trucks) {
          expect(trucks, hasLength(1));
          expect(trucks.first.id, 'truck_1');
        },
      );
      verifyNever(() => firebaseSource.getTrucksStream());
    });
  });

  group('TruckRepositoryImpl.getTruckById', () {
    test('returns Right(Truck) when found', () async {
      when(() => firebaseSource.getTruckById('truck_1'))
          .thenAnswer((_) async => sampleDto);

      final result = await repository.getTruckById('truck_1');

      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('expected Right, got Left($failure)'),
        (truck) => expect(truck.id, 'truck_1'),
      );
    });

    test('returns Left(NotFoundFailure) when truck does not exist', () async {
      when(() => firebaseSource.getTruckById('missing'))
          .thenAnswer((_) async => null);

      final result = await repository.getTruckById('missing');

      expect(result.isLeft(), true);
    });
  });

  group('TruckRepositoryImpl.updateTruckLocation', () {
    test('returns Right(null) on success', () async {
      when(() => firebaseSource.updateTruckLocation(any(), any(), any()))
          .thenAnswer((_) async {});

      final result =
          await repository.updateTruckLocation('truck_1', 31.5, 34.5);

      expect(result.isRight(), true);
    });

    test('returns Left(ServerFailure) on exception', () async {
      when(() => firebaseSource.updateTruckLocation(any(), any(), any()))
          .thenThrow(Exception('network error'));

      final result =
          await repository.updateTruckLocation('truck_1', 31.5, 34.5);

      expect(result.isLeft(), true);
    });
  });
}
