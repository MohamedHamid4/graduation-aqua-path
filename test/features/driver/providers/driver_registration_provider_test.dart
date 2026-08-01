import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:aquapath/core/auth/user_role.dart';
import 'package:aquapath/core/errors/failures.dart';
import 'package:aquapath/features/auth/domain/entities/app_user.dart';
import 'package:aquapath/features/auth/domain/repositories/auth_repository.dart';
import 'package:aquapath/features/driver/domain/entities/driver_profile.dart';
import 'package:aquapath/features/driver/domain/repositories/driver_repository.dart';
import 'package:aquapath/features/driver/presentation/providers/driver_registration_provider.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDriverRepository extends Mock implements DriverRepository {}

const _testUser = AppUser(uid: 'driver-uid-1', email: 'd@aquapath.com');

void main() {
  late MockAuthRepository mockAuth;
  late MockDriverRepository mockDriverRepo;

  setUpAll(() {
    registerFallbackValue(
      DriverProfile(
        uid: 'x',
        firstName: 'x',
        lastName: 'x',
        phone: 'x',
        truckPlateNumber: 'x',
        truckCapacity: 1,
        licenseNumber: 'x',
        assignedArea: 'x',
        registeredAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    mockAuth = MockAuthRepository();
    mockDriverRepo = MockDriverRepository();
    when(() => mockAuth.currentUser).thenReturn(_testUser);
    when(() => mockAuth.waitForRoleClaim())
        .thenAnswer((_) async => UserRole.driver);

    if (GetIt.I.isRegistered<AuthRepository>()) {
      GetIt.I.unregister<AuthRepository>();
    }
    if (GetIt.I.isRegistered<DriverRepository>()) {
      GetIt.I.unregister<DriverRepository>();
    }
    GetIt.I.registerSingleton<AuthRepository>(mockAuth);
    GetIt.I.registerSingleton<DriverRepository>(mockDriverRepo);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('DriverRegistrationNotifier — initial state', () {
    test('defaults are empty/unsubmitted', () {
      final container = makeContainer();
      final state = container.read(driverRegistrationProvider);

      expect(state.firstName, isEmpty);
      expect(state.lastName, isEmpty);
      expect(state.phone, isEmpty);
      expect(state.truckPlateNumber, isEmpty);
      expect(state.truckCapacity, 10000);
      expect(state.isSubmitting, false);
      expect(state.isSuccess, false);
    });
  });

  group('DriverRegistrationNotifier — validation', () {
    test('submit with all fields empty sets validationError', () async {
      final container = makeContainer();
      await container.read(driverRegistrationProvider.notifier).submit();

      final state = container.read(driverRegistrationProvider);
      expect(state.validationError, isNotNull);
      expect(state.isSubmitting, false);
    });

    test('setFirstName clears a previous validationError', () async {
      final container = makeContainer();
      final notifier = container.read(driverRegistrationProvider.notifier);

      await notifier.submit();
      expect(
        container.read(driverRegistrationProvider).validationError,
        isNotNull,
      );

      notifier.setFirstName('أحمد');
      expect(
        container.read(driverRegistrationProvider).validationError,
        isNull,
      );
    });

    test('missing phone after name is filled still blocks submit', () async {
      final container = makeContainer();
      final notifier = container.read(driverRegistrationProvider.notifier);
      notifier.setFirstName('أحمد');
      notifier.setLastName('محمد');

      await notifier.submit();
      expect(
        container.read(driverRegistrationProvider).validationError,
        isNotNull,
      );
      verifyNever(() => mockDriverRepo.registerDriverProfile(any()));
    });

    test('a phone number that is not exactly 10 digits blocks submit',
        () async {
      final container = makeContainer();
      final notifier = container.read(driverRegistrationProvider.notifier);
      notifier.setFirstName('أحمد');
      notifier.setLastName('محمد');
      notifier.setPhone('05912345'); // 8 digits — too short
      notifier.setTruckPlateNumber('12-345-67');
      notifier.setLicenseNumber('LIC-9988');
      notifier.setAssignedArea('الشجاعية');

      await notifier.submit();

      expect(
        container.read(driverRegistrationProvider).validationError,
        isNotNull,
      );
      verifyNever(() => mockDriverRepo.registerDriverProfile(any()));
    });
  });

  group('DriverRegistrationNotifier — submit', () {
    void fillValidForm(DriverRegistrationNotifier n) {
      n.setFirstName('أحمد');
      n.setLastName('محمد');
      n.setPhone('0591234567');
      n.setTruckPlateNumber('12-345-67');
      n.setLicenseNumber('LIC-9988');
      n.setAssignedArea('الشجاعية');
    }

    test('success sets isSuccess and calls registerDriverProfile', () async {
      when(() => mockDriverRepo.registerDriverProfile(any()))
          .thenAnswer((_) async => const Right(unit));

      final container = makeContainer();
      final notifier = container.read(driverRegistrationProvider.notifier);
      fillValidForm(notifier);

      await notifier.submit();

      final state = container.read(driverRegistrationProvider);
      expect(state.isSuccess, true);
      expect(state.isSubmitting, false);
      verify(() => mockDriverRepo.registerDriverProfile(any())).called(1);
      verify(() => mockAuth.waitForRoleClaim()).called(1);
    });

    test('failure surfaces errorMessage, not isSuccess', () async {
      when(() => mockDriverRepo.registerDriverProfile(any())).thenAnswer(
        (_) async => const Left(ServerFailure('فشل تسجيل بيانات السائق')),
      );

      final container = makeContainer();
      final notifier = container.read(driverRegistrationProvider.notifier);
      fillValidForm(notifier);

      await notifier.submit();

      final state = container.read(driverRegistrationProvider);
      expect(state.isSuccess, false);
      expect(state.errorMessage, isNotNull);
    });

    test('submit without a signed-in user sets errorMessage', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final container = makeContainer();
      final notifier = container.read(driverRegistrationProvider.notifier);
      fillValidForm(notifier);

      await notifier.submit();

      final state = container.read(driverRegistrationProvider);
      expect(state.errorMessage, isNotNull);
      verifyNever(() => mockDriverRepo.registerDriverProfile(any()));
    });

    test('profile passed to repository carries the entered fields', () async {
      when(() => mockDriverRepo.registerDriverProfile(any()))
          .thenAnswer((_) async => const Right(unit));

      final container = makeContainer();
      final notifier = container.read(driverRegistrationProvider.notifier);
      fillValidForm(notifier);
      notifier.setTruckCapacity(12000);

      await notifier.submit();

      final captured = verify(
        () => mockDriverRepo.registerDriverProfile(captureAny()),
      ).captured.single as DriverProfile;

      expect(captured.uid, 'driver-uid-1');
      expect(captured.fullName, 'أحمد محمد');
      expect(captured.assignedArea, 'الشجاعية');
      expect(captured.truckCapacity, 12000);
    });
  });
}
