import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:aquapath/core/errors/failures.dart';
import 'package:aquapath/features/parking/domain/entities/parking_spot.dart';
import 'package:aquapath/features/parking/domain/repositories/parking_spot_repository.dart';
import 'package:aquapath/features/parking/presentation/providers/parking_spot_providers.dart';

class MockParkingSpotRepository extends Mock implements ParkingSpotRepository {}

void main() {
  late MockParkingSpotRepository mockRepo;

  final sampleSpot = ParkingSpot(
    id: 'spot_1',
    latitude: 31.50,
    longitude: 34.46,
    stopCount: 4,
    isVerified: true,
    lastStoppedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    mockRepo = MockParkingSpotRepository();
    if (GetIt.I.isRegistered<ParkingSpotRepository>()) {
      GetIt.I.unregister<ParkingSpotRepository>();
    }
    GetIt.I.registerSingleton<ParkingSpotRepository>(mockRepo);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  test('emits the verified spots list on success', () async {
    when(() => mockRepo.watchVerifiedSpots())
        .thenAnswer((_) => Stream.value(Right([sampleSpot])));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(verifiedParkingSpotsProvider.future);

    expect(result, hasLength(1));
    expect(result.first.id, 'spot_1');
  });

  test('falls back to an empty list when the repository errors', () async {
    when(() => mockRepo.watchVerifiedSpots()).thenAnswer(
      (_) => Stream.value(const Left(ServerFailure('down'))),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(verifiedParkingSpotsProvider.future);

    expect(result, isEmpty);
  });
}
