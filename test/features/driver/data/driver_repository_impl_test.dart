import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:aquapath/core/offline/offline_write_queue_service.dart';
import 'package:aquapath/features/driver/data/datasources/driver_firebase_source.dart';
import 'package:aquapath/features/driver/data/repositories/driver_repository_impl.dart';
import 'package:aquapath/features/driver/domain/entities/driver_profile.dart';

class MockDriverFirebaseSource extends Mock implements DriverFirebaseSource {}

class MockOfflineWriteQueueService extends Mock
    implements OfflineWriteQueueService {}

void main() {
  late MockDriverFirebaseSource mockSource;
  late MockOfflineWriteQueueService mockOfflineQueue;
  late DriverRepositoryImpl repo;

  setUp(() {
    mockSource = MockDriverFirebaseSource();
    mockOfflineQueue = MockOfflineWriteQueueService();
    repo = DriverRepositoryImpl(
      mockSource,
      offlineQueue: mockOfflineQueue,
    );
  });

  group('DriverRepositoryImpl.isDriver', () {
    test('returns true when the source confirms a driver profile exists',
        () async {
      when(() => mockSource.isDriver('uid-1')).thenAnswer((_) async => true);

      expect(await repo.isDriver('uid-1'), true);
    });

    test('returns false when no driver profile exists', () async {
      when(() => mockSource.isDriver('uid-1')).thenAnswer((_) async => false);

      expect(await repo.isDriver('uid-1'), false);
    });

    test('fails closed (returns false) when the Firestore check throws',
        () async {
      when(() => mockSource.isDriver('uid-1'))
          .thenThrow(Exception('network error'));

      // Critical safety property: an inability to confirm driver status
      // must never accidentally grant driver-only screens — the router
      // and splash screen both trust this return value directly.
      expect(await repo.isDriver('uid-1'), false);
    });
  });

  group('DriverRepositoryImpl.registerDriverProfile', () {
    final profile = DriverProfile(
      uid: 'uid-1',
      fullName: 'أحمد محمد',
      phone: '0591234567',
      truckPlateNumber: '12-345-67',
      truckCapacity: 10000,
      licenseNumber: 'LIC-1',
      registeredAt: DateTime(2026, 1, 1),
    );

    test('success returns Right(unit)', () async {
      when(() => mockSource.registerDriverProfile(profile))
          .thenAnswer((_) async {});

      final result = await repo.registerDriverProfile(profile);

      expect(result.isRight(), true);
      verify(() => mockSource.registerDriverProfile(profile)).called(1);
    });

    test('failure returns a ServerFailure with an Arabic message', () async {
      when(() => mockSource.registerDriverProfile(profile))
          .thenThrow(Exception('firestore down'));

      final result = await repo.registerDriverProfile(profile);

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure.message, isNotEmpty),
        (_) => fail('expected Left'),
      );
    });
  });

  group('DriverRepositoryImpl.registerDriverProfile — offline', () {
    final profile = DriverProfile(
      uid: 'uid-offline',
      fullName: 'سارة يوسف',
      phone: '0599876543',
      truckPlateNumber: '9-111-22',
      truckCapacity: 8000,
      licenseNumber: 'LIC-2',
      registeredAt: DateTime(2026, 1, 1),
    );

    test(
        'queues the write when the actual write fails for a connectivity '
        'reason', () async {
      // The write is always attempted first (not gated on a pre-check) —
      // only a genuine connectivity failure from the write itself queues
      // it. See HouseholdRepositoryImpl.saveHousehold for the reasoning.
      when(() => mockSource.registerDriverProfile(profile)).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      when(() => mockOfflineQueue.enqueue(
            collection: any(named: 'collection'),
            docId: any(named: 'docId'),
            data: any(named: 'data'),
          )).thenAnswer((_) async {});

      final result = await repo.registerDriverProfile(profile);

      expect(result.isRight(), true);
      verify(() => mockOfflineQueue.enqueue(
            collection: 'drivers',
            docId: 'uid-offline',
            data: profile.toMap(),
          )).called(1);
    });

    test('does NOT queue and reports the real failure on permission-denied',
        () async {
      when(() => mockSource.registerDriverProfile(profile)).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      final result = await repo.registerDriverProfile(profile);

      expect(result.isLeft(), true);
      verifyNever(() => mockOfflineQueue.enqueue(
            collection: any(named: 'collection'),
            docId: any(named: 'docId'),
            data: any(named: 'data'),
          ));
    });
  });

  group('DriverRepositoryImpl.getDriverProfile', () {
    test('returns null wrapped in Right when no profile exists', () async {
      when(() => mockSource.getDriverProfile('uid-1'))
          .thenAnswer((_) async => null);

      final result = await repo.getDriverProfile('uid-1');

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('expected Right'),
        (profile) => expect(profile, isNull),
      );
    });

    test('returns the profile wrapped in Right when it exists', () async {
      final profile = DriverProfile(
        uid: 'uid-1',
        fullName: 'خالد عمر',
        phone: '0599999999',
        truckPlateNumber: '99-999-99',
        truckCapacity: 8000,
        licenseNumber: 'LIC-9',
        registeredAt: DateTime(2026, 1, 1),
      );
      when(() => mockSource.getDriverProfile('uid-1'))
          .thenAnswer((_) async => profile);

      final result = await repo.getDriverProfile('uid-1');

      result.fold(
        (_) => fail('expected Right'),
        (p) => expect(p?.fullName, 'خالد عمر'),
      );
    });
  });

  group('DriverRepositoryImpl.updateRouteStatus', () {
    test('success returns Right(unit)', () async {
      when(() => mockSource.updateRouteStatus(
            routeId: 'r1',
            status: 'completed',
          )).thenAnswer((_) async {});

      final result =
          await repo.updateRouteStatus(routeId: 'r1', status: 'completed');

      expect(result.isRight(), true);
    });

    test('failure returns a Left with Arabic message', () async {
      when(() => mockSource.updateRouteStatus(
            routeId: 'r1',
            status: 'completed',
          )).thenThrow(Exception('offline'));

      final result =
          await repo.updateRouteStatus(routeId: 'r1', status: 'completed');

      expect(result.isLeft(), true);
    });
  });
}
