import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:aquapath/core/errors/failures.dart';
import 'package:aquapath/features/auth/domain/entities/app_user.dart';
import 'package:aquapath/features/auth/domain/repositories/auth_repository.dart';
import 'package:aquapath/features/driver/domain/entities/driver_route.dart';
import 'package:aquapath/features/driver/domain/repositories/driver_repository.dart';
import 'package:aquapath/features/driver/presentation/providers/driver_location_provider.dart';
import 'package:aquapath/features/parking/domain/repositories/parking_spot_repository.dart';
import 'package:aquapath/features/trucks/domain/repositories/truck_repository.dart';
import 'package:aquapath/shared/services/location_service.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockTruckRepository extends Mock implements TruckRepository {}

class MockDriverRepository extends Mock implements DriverRepository {}

class MockParkingSpotRepository extends Mock implements ParkingSpotRepository {}

class MockLocationService extends Mock implements LocationService {}

const _testUser = AppUser(
  uid: 'driver-uid-1',
  email: 'd@aquapath.com',
  displayName: 'أحمد محمد',
);

final _testRoute = DriverRoute(
  id: 'route-1',
  driverUid: 'driver-uid-1',
  areaName: 'الشجاعية',
  startLat: 31.50,
  startLng: 34.46,
  endLat: 31.52,
  endLng: 34.48,
  scheduledTime: DateTime(2026, 1, 1, 8),
  timeSlot: '8:00 صباحاً',
);

void main() {
  late MockAuthRepository mockAuth;
  late MockTruckRepository mockTruckRepo;
  late MockDriverRepository mockDriverRepo;
  late MockParkingSpotRepository mockParkingRepo;
  late MockLocationService mockLocation;

  setUp(() {
    mockAuth = MockAuthRepository();
    mockTruckRepo = MockTruckRepository();
    mockDriverRepo = MockDriverRepository();
    mockParkingRepo = MockParkingSpotRepository();
    mockLocation = MockLocationService();

    when(() => mockAuth.currentUser).thenReturn(_testUser);
    when(() => mockLocation.getCurrentPosition())
        .thenAnswer((_) async => (lat: 31.501, lng: 34.461));
    when(() => mockLocation.requestBackgroundPermission())
        .thenAnswer((_) async => true);
    // Empty, never-emitting stream: startTrip() subscribes to this so
    // the background-service-backed path is exercised without the test
    // depending on real stream timing — _broadcastOnce falls back to
    // getCurrentPosition() whenever _latestStreamPos is still null,
    // which is exactly this case, so existing assertions against the
    // getCurrentPosition() fixture value are unaffected.
    when(() => mockLocation.driverTripPositionStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockParkingRepo.registerStop(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          driverUid: any(named: 'driverUid'),
          areaName: any(named: 'areaName'),
        )).thenAnswer((_) async => const Right(unit));

    if (GetIt.I.isRegistered<AuthRepository>()) {
      GetIt.I.unregister<AuthRepository>();
    }
    if (GetIt.I.isRegistered<TruckRepository>()) {
      GetIt.I.unregister<TruckRepository>();
    }
    if (GetIt.I.isRegistered<DriverRepository>()) {
      GetIt.I.unregister<DriverRepository>();
    }
    if (GetIt.I.isRegistered<ParkingSpotRepository>()) {
      GetIt.I.unregister<ParkingSpotRepository>();
    }
    if (GetIt.I.isRegistered<LocationService>()) {
      GetIt.I.unregister<LocationService>();
    }
    GetIt.I.registerSingleton<AuthRepository>(mockAuth);
    GetIt.I.registerSingleton<TruckRepository>(mockTruckRepo);
    GetIt.I.registerSingleton<DriverRepository>(mockDriverRepo);
    GetIt.I.registerSingleton<ParkingSpotRepository>(mockParkingRepo);
    GetIt.I.registerSingleton<LocationService>(mockLocation);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('DriverLocationNotifier — initial state', () {
    test('trip is inactive with no route', () {
      final container = makeContainer();
      final state = container.read(driverLocationProvider);

      expect(state.isActive, false);
      expect(state.currentRoute, isNull);
      expect(state.lastBroadcastAt, isNull);
    });
  });

  group('DriverLocationNotifier — startTrip', () {
    test('success marks trip active and captures start position', () async {
      when(() => mockTruckRepo.startTrip(
            truckId: any(named: 'truckId'),
            driverName: any(named: 'driverName'),
            routeName: any(named: 'routeName'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            capacity: any(named: 'capacity'),
          )).thenAnswer((_) async => const Right(null));
      when(() => mockDriverRepo.updateRouteStatus(
            routeId: any(named: 'routeId'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => const Right(unit));

      final container = makeContainer();
      final notifier = container.read(driverLocationProvider.notifier);

      await notifier.startTrip(_testRoute);
      // Let the fire-and-forget updateRouteStatus call settle.
      await Future<void>.delayed(Duration.zero);

      final state = container.read(driverLocationProvider);
      expect(state.isActive, true);
      expect(state.currentRoute, _testRoute);
      expect(state.lastLat, 31.501);
      expect(state.lastLng, 34.461);
      expect(state.lastBroadcastAt, isNotNull);

      verify(() => mockTruckRepo.startTrip(
            truckId: 'driver-uid-1',
            driverName: 'أحمد محمد',
            routeName: 'الشجاعية',
            lat: 31.501,
            lng: 34.461,
            capacity: any(named: 'capacity'),
          )).called(1);
    });

    test('marks the route in_progress once the trip starts', () async {
      when(() => mockTruckRepo.startTrip(
            truckId: any(named: 'truckId'),
            driverName: any(named: 'driverName'),
            routeName: any(named: 'routeName'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            capacity: any(named: 'capacity'),
          )).thenAnswer((_) async => const Right(null));
      when(() => mockDriverRepo.updateRouteStatus(
            routeId: any(named: 'routeId'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => const Right(unit));

      final container = makeContainer();
      await container
          .read(driverLocationProvider.notifier)
          .startTrip(_testRoute);
      await Future<void>.delayed(Duration.zero);

      verify(() => mockDriverRepo.updateRouteStatus(
            routeId: 'route-1',
            status: 'in_progress',
          )).called(1);
    });

    test('repository failure surfaces errorMessage, trip stays inactive',
        () async {
      when(() => mockTruckRepo.startTrip(
            truckId: any(named: 'truckId'),
            driverName: any(named: 'driverName'),
            routeName: any(named: 'routeName'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            capacity: any(named: 'capacity'),
          )).thenAnswer((_) async => const Left(ServerFailure('فشل')));

      final container = makeContainer();
      await container
          .read(driverLocationProvider.notifier)
          .startTrip(_testRoute);

      final state = container.read(driverLocationProvider);
      expect(state.isActive, false);
      expect(state.errorMessage, isNotNull);
    });

    test('no signed-in user sets errorMessage without calling repository',
        () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final container = makeContainer();
      await container
          .read(driverLocationProvider.notifier)
          .startTrip(_testRoute);

      final state = container.read(driverLocationProvider);
      expect(state.isActive, false);
      expect(state.errorMessage, isNotNull);
      verifyNever(() => mockTruckRepo.startTrip(
            truckId: any(named: 'truckId'),
            driverName: any(named: 'driverName'),
            routeName: any(named: 'routeName'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            capacity: any(named: 'capacity'),
          ));
    });

    test('calling startTrip twice while active is a no-op the second time',
        () async {
      when(() => mockTruckRepo.startTrip(
            truckId: any(named: 'truckId'),
            driverName: any(named: 'driverName'),
            routeName: any(named: 'routeName'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            capacity: any(named: 'capacity'),
          )).thenAnswer((_) async => const Right(null));
      when(() => mockDriverRepo.updateRouteStatus(
            routeId: any(named: 'routeId'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => const Right(unit));

      final container = makeContainer();
      final notifier = container.read(driverLocationProvider.notifier);

      await notifier.startTrip(_testRoute);
      await Future<void>.delayed(Duration.zero);
      await notifier.startTrip(_testRoute);

      verify(() => mockTruckRepo.startTrip(
            truckId: any(named: 'truckId'),
            driverName: any(named: 'driverName'),
            routeName: any(named: 'routeName'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            capacity: any(named: 'capacity'),
          )).called(1);
    });
  });

  group('DriverLocationNotifier — debugBroadcastNow (simulated tick)', () {
    test('writes the latest position via updateTruckLocation', () async {
      when(() => mockTruckRepo.startTrip(
            truckId: any(named: 'truckId'),
            driverName: any(named: 'driverName'),
            routeName: any(named: 'routeName'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            capacity: any(named: 'capacity'),
          )).thenAnswer((_) async => const Right(null));
      when(() => mockDriverRepo.updateRouteStatus(
            routeId: any(named: 'routeId'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => const Right(unit));
      when(() => mockTruckRepo.updateTruckLocation(any(), any(), any()))
          .thenAnswer((_) async => const Right(null));

      final container = makeContainer();
      final notifier = container.read(driverLocationProvider.notifier);
      await notifier.startTrip(_testRoute);
      await Future<void>.delayed(Duration.zero);

      // Simulate the device having moved before the next scheduled tick.
      when(() => mockLocation.getCurrentPosition())
          .thenAnswer((_) async => (lat: 31.505, lng: 34.465));

      await notifier.debugBroadcastNow();

      final state = container.read(driverLocationProvider);
      expect(state.lastLat, 31.505);
      expect(state.lastLng, 34.465);
      verify(() => mockTruckRepo.updateTruckLocation(
            'driver-uid-1',
            31.505,
            34.465,
          )).called(1);
    });

    test('is a no-op when no trip is active', () async {
      final container = makeContainer();
      await container.read(driverLocationProvider.notifier).debugBroadcastNow();

      verifyNever(() => mockTruckRepo.updateTruckLocation(any(), any(), any()));
    });
  });

  group('DriverLocationNotifier — parking stop detection', () {
    test('reports a stop when the truck barely moves between ticks', () async {
      when(() => mockTruckRepo.startTrip(
            truckId: any(named: 'truckId'),
            driverName: any(named: 'driverName'),
            routeName: any(named: 'routeName'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            capacity: any(named: 'capacity'),
          )).thenAnswer((_) async => const Right(null));
      when(() => mockDriverRepo.updateRouteStatus(
            routeId: any(named: 'routeId'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => const Right(unit));
      when(() => mockTruckRepo.updateTruckLocation(any(), any(), any()))
          .thenAnswer((_) async => const Right(null));

      final container = makeContainer();
      final notifier = container.read(driverLocationProvider.notifier);
      await notifier.startTrip(_testRoute);
      await Future<void>.delayed(Duration.zero);

      // Next tick lands ~5m away from the trip's starting point — well
      // under the 40m "didn't really move" threshold.
      when(() => mockLocation.getCurrentPosition())
          .thenAnswer((_) async => (lat: 31.50104, lng: 34.46104));

      await notifier.debugBroadcastNow();

      expect(container.read(driverLocationProvider).isCurrentlyStopped, true);
      verify(() => mockParkingRepo.registerStop(
            latitude: 31.50104,
            longitude: 34.46104,
            driverUid: any(named: 'driverUid'),
            areaName: any(named: 'areaName'),
          )).called(1);
    });

    test('does not re-report the same stop on every tick while stationary',
        () async {
      when(() => mockTruckRepo.startTrip(
            truckId: any(named: 'truckId'),
            driverName: any(named: 'driverName'),
            routeName: any(named: 'routeName'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            capacity: any(named: 'capacity'),
          )).thenAnswer((_) async => const Right(null));
      when(() => mockDriverRepo.updateRouteStatus(
            routeId: any(named: 'routeId'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => const Right(unit));
      when(() => mockTruckRepo.updateTruckLocation(any(), any(), any()))
          .thenAnswer((_) async => const Right(null));

      final container = makeContainer();
      final notifier = container.read(driverLocationProvider.notifier);
      await notifier.startTrip(_testRoute);
      await Future<void>.delayed(Duration.zero);

      when(() => mockLocation.getCurrentPosition())
          .thenAnswer((_) async => (lat: 31.50104, lng: 34.46104));
      await notifier.debugBroadcastNow(); // 1st stationary tick — reports
      await notifier.debugBroadcastNow(); // 2nd — same spot, no re-report
      await notifier.debugBroadcastNow(); // 3rd — same spot, no re-report

      verify(() => mockParkingRepo.registerStop(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            driverUid: any(named: 'driverUid'),
            areaName: any(named: 'areaName'),
          )).called(1);
    });

    test('moving away and stopping again reports a second stop', () async {
      when(() => mockTruckRepo.startTrip(
            truckId: any(named: 'truckId'),
            driverName: any(named: 'driverName'),
            routeName: any(named: 'routeName'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            capacity: any(named: 'capacity'),
          )).thenAnswer((_) async => const Right(null));
      when(() => mockDriverRepo.updateRouteStatus(
            routeId: any(named: 'routeId'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => const Right(unit));
      when(() => mockTruckRepo.updateTruckLocation(any(), any(), any()))
          .thenAnswer((_) async => const Right(null));

      final container = makeContainer();
      final notifier = container.read(driverLocationProvider.notifier);
      await notifier.startTrip(_testRoute);
      await Future<void>.delayed(Duration.zero);

      // Stop #1.
      when(() => mockLocation.getCurrentPosition())
          .thenAnswer((_) async => (lat: 31.50104, lng: 34.46104));
      await notifier.debugBroadcastNow();

      // Drives well away.
      when(() => mockLocation.getCurrentPosition())
          .thenAnswer((_) async => (lat: 31.510, lng: 34.470));
      await notifier.debugBroadcastNow();
      expect(container.read(driverLocationProvider).isCurrentlyStopped, false);

      // Stop #2, at a different location.
      when(() => mockLocation.getCurrentPosition())
          .thenAnswer((_) async => (lat: 31.51001, lng: 34.47001));
      await notifier.debugBroadcastNow();

      expect(container.read(driverLocationProvider).isCurrentlyStopped, true);
      verify(() => mockParkingRepo.registerStop(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            driverUid: any(named: 'driverUid'),
            areaName: any(named: 'areaName'),
          )).called(2);
    });

    test('a large jump between ticks is not treated as a stop', () async {
      when(() => mockTruckRepo.startTrip(
            truckId: any(named: 'truckId'),
            driverName: any(named: 'driverName'),
            routeName: any(named: 'routeName'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            capacity: any(named: 'capacity'),
          )).thenAnswer((_) async => const Right(null));
      when(() => mockDriverRepo.updateRouteStatus(
            routeId: any(named: 'routeId'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => const Right(unit));
      when(() => mockTruckRepo.updateTruckLocation(any(), any(), any()))
          .thenAnswer((_) async => const Right(null));

      final container = makeContainer();
      final notifier = container.read(driverLocationProvider.notifier);
      await notifier.startTrip(_testRoute);
      await Future<void>.delayed(Duration.zero);

      when(() => mockLocation.getCurrentPosition())
          .thenAnswer((_) async => (lat: 31.505, lng: 34.465));
      await notifier.debugBroadcastNow();

      expect(container.read(driverLocationProvider).isCurrentlyStopped, false);
      verifyNever(() => mockParkingRepo.registerStop(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            driverUid: any(named: 'driverUid'),
            areaName: any(named: 'areaName'),
          ));
    });
  });

  group('DriverLocationNotifier — endTrip', () {
    test('marks trip inactive, ends the truck doc, completes the route',
        () async {
      when(() => mockTruckRepo.startTrip(
            truckId: any(named: 'truckId'),
            driverName: any(named: 'driverName'),
            routeName: any(named: 'routeName'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            capacity: any(named: 'capacity'),
          )).thenAnswer((_) async => const Right(null));
      when(() => mockDriverRepo.updateRouteStatus(
            routeId: any(named: 'routeId'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => const Right(unit));
      when(() => mockTruckRepo.endTrip(any()))
          .thenAnswer((_) async => const Right(null));

      final container = makeContainer();
      final notifier = container.read(driverLocationProvider.notifier);
      await notifier.startTrip(_testRoute);
      await Future<void>.delayed(Duration.zero);

      await notifier.endTrip();

      final state = container.read(driverLocationProvider);
      expect(state.isActive, false);
      expect(state.currentRoute, isNull);
      verify(() => mockTruckRepo.endTrip('driver-uid-1')).called(1);
      verify(() => mockDriverRepo.updateRouteStatus(
            routeId: 'route-1',
            status: 'completed',
          )).called(1);
    });

    test('is a no-op when no trip is active', () async {
      final container = makeContainer();
      await container.read(driverLocationProvider.notifier).endTrip();

      verifyNever(() => mockTruckRepo.endTrip(any()));
    });
  });
}
