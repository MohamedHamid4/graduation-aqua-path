import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:aquapath/core/errors/failures.dart';
import 'package:aquapath/core/security/secure_storage_service.dart';
import 'package:aquapath/core/auth/user_role.dart';
import 'package:aquapath/features/auth/domain/entities/app_user.dart';
import 'package:aquapath/features/auth/domain/repositories/auth_repository.dart';
import 'package:aquapath/features/registration/domain/repositories/household_repository.dart';
import 'package:aquapath/features/registration/presentation/providers/registration_provider.dart';
import 'package:aquapath/shared/models/household_model.dart';
import 'package:aquapath/shared/services/priority_service.dart';
import 'package:aquapath/core/errors/failure_messages.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockHouseholdRepository extends Mock implements HouseholdRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockPriorityService extends Mock implements PriorityService {}

const _testUser = AppUser(uid: 'resident-uid-1', email: 'r@aquapath.com');

void main() {
  late MockAuthRepository mockAuth;
  late MockHouseholdRepository mockHouseholdRepo;
  late MockSecureStorageService mockStorage;
  late MockPriorityService mockPriority;

  setUpAll(() {
    registerFallbackValue(
      HouseholdModel(
        id: 'x',
        familyName: 'عائلة تجريبية',
        areaName: 'x',
        householdSize: 1,
        registeredAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    mockAuth = MockAuthRepository();
    mockHouseholdRepo = MockHouseholdRepository();
    mockStorage = MockSecureStorageService();
    mockPriority = MockPriorityService();

    when(() => mockAuth.currentUser).thenReturn(_testUser);
    when(() => mockAuth.waitForRoleClaim())
        .thenAnswer((_) async => UserRole.resident);

    final sl = GetIt.I;
    if (sl.isRegistered<AuthRepository>()) sl.unregister<AuthRepository>();
    if (sl.isRegistered<HouseholdRepository>()) {
      sl.unregister<HouseholdRepository>();
    }
    if (sl.isRegistered<SecureStorageService>()) {
      sl.unregister<SecureStorageService>();
    }
    if (sl.isRegistered<PriorityService>()) sl.unregister<PriorityService>();

    sl.registerSingleton<AuthRepository>(mockAuth);
    sl.registerSingleton<HouseholdRepository>(mockHouseholdRepo);
    sl.registerSingleton<SecureStorageService>(mockStorage);
    sl.registerSingleton<PriorityService>(mockPriority);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('RegistrationNotifier — initial state', () {
    test('defaults are correct', () {
      final container = makeContainer();
      final state = container.read(registrationProvider);

      expect(state.selectedArea, 'الشجاعية');
      expect(state.householdSize, 4);
      expect(state.hasElderly, false);
      expect(state.hasSick, false);
      expect(state.hasChildren, false);
      expect(state.isSubmitting, false);
      expect(state.isSuccess, false);
      expect(state.isEditingExisting, false);
      expect(state.familyName, '');
    });
  });

  group('RegistrationNotifier — state updates', () {
    test('setFamilyName updates familyName', () {
      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);

      notifier.setFamilyName('عائلة أبو أحمد');
      expect(container.read(registrationProvider).familyName, 'عائلة أبو أحمد');
    });

    test('setArea updates area and clears validation', () {
      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);

      notifier.setArea('الرمال');
      expect(container.read(registrationProvider).selectedArea, 'الرمال');
    });

    test('setHouseholdSize clamps values between 1 and 20', () {
      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);

      notifier.setHouseholdSize(25);
      expect(container.read(registrationProvider).householdSize, 20);

      notifier.setHouseholdSize(0);
      expect(container.read(registrationProvider).householdSize, 1);
    });

    test('switch updates toggle vulnerability flags', () {
      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);

      notifier.setHasElderly(value: true);
      notifier.setHasSick(value: true);
      notifier.setHasChildren(value: true);

      final state = container.read(registrationProvider);
      expect(state.hasElderly, true);
      expect(state.hasSick, true);
      expect(state.hasChildren, true);
    });
  });

  group('RegistrationNotifier — validation', () {
    test('submit without family name fails validation', () async {
      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);

      notifier.setFamilyName('');
      await notifier.submit();

      final state = container.read(registrationProvider);
      expect(state.validationError, 'يرجى إدخال اسم العائلة');
      expect(state.isSubmitting, false);
      verifyNever(
        () => mockHouseholdRepo.saveHousehold(
          uid: any(named: 'uid'),
          household: any(named: 'household'),
        ),
      );
    });

    test('validation fails if area is empty', () async {
      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);

      notifier.setFamilyName('عائلة تجريبية');
      notifier.setArea('');
      await notifier.submit();

      final state = container.read(registrationProvider);
      expect(state.validationError, FailureMessages.areaRequired);
      expect(state.isSubmitting, false);
      verifyNever(
        () => mockHouseholdRepo.saveHousehold(
          uid: any(named: 'uid'),
          household: any(named: 'household'),
        ),
      );
    });
  });

  group('RegistrationNotifier — loadExistingIfAny', () {
    test('prefills the form from an existing household', () async {
      when(() => mockHouseholdRepo.getHousehold('resident-uid-1')).thenAnswer(
        (_) async => Right(
          HouseholdModel(
            id: 'resident-uid-1',
            familyName: 'عائلة تجريبية',
            areaName: 'خان يونس',
            householdSize: 7,
            hasElderly: true,
            registeredAt: DateTime(2024),
          ),
        ),
      );

      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);
      await notifier.loadExistingIfAny();

      final state = container.read(registrationProvider);
      expect(state.familyName, 'عائلة تجريبية');
      expect(state.selectedArea, 'خان يونس');
      expect(state.householdSize, 7);
      expect(state.hasElderly, true);
      expect(state.isEditingExisting, true);
    });

    test('does nothing when no household is registered yet', () async {
      when(() => mockHouseholdRepo.getHousehold('resident-uid-1'))
          .thenAnswer((_) async => const Right(null));

      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);
      await notifier.loadExistingIfAny();

      final state = container.read(registrationProvider);
      expect(state.selectedArea, 'الشجاعية');
      expect(state.isEditingExisting, false);
    });

    test('does nothing when nobody is signed in', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);
      await notifier.loadExistingIfAny();

      verifyNever(() => mockHouseholdRepo.getHousehold(any()));
    });

    test(
        'clears a stale isSuccess left over from an earlier submit before '
        'reopening for edit (regression: re-entering the edit screen no '
        'longer auto-pops with a false "updated" message)', () async {
      when(() => mockHouseholdRepo.getHousehold('resident-uid-1')).thenAnswer(
        (_) async => Right(
          HouseholdModel(
            id: 'resident-uid-1',
            familyName: 'عائلة تجريبية',
            areaName: 'خان يونس',
            householdSize: 7,
            registeredAt: DateTime(2024),
          ),
        ),
      );
      when(() => mockHouseholdRepo.saveHousehold(
            uid: any(named: 'uid'),
            household: any(named: 'household'),
          )).thenAnswer((_) async => Right(unit));
      when(() => mockStorage.setRegistrationComplete(
            householdId: any(named: 'householdId'),
          )).thenAnswer((_) async {});
      when(() => mockStorage.saveArea(any())).thenAnswer((_) async {});
      when(() => mockPriority.calculatePriority(
            householdCount: any(named: 'householdCount'),
            vulnerabilityScore: any(named: 'vulnerabilityScore'),
            daysSinceServed: any(named: 'daysSinceServed'),
          )).thenReturn(10);

      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);

      // Simulate a prior successful submit earlier in the app session
      // (e.g. during first-run onboarding) — this is what leaves
      // isSuccess stuck true on this long-lived provider.
      notifier.setFamilyName('عائلة تجريبية');
      await notifier.submit();
      expect(container.read(registrationProvider).isSuccess, true);

      // Re-opening the edit screen later calls this — it must not carry
      // the stale isSuccess forward into the new state it emits.
      await notifier.loadExistingIfAny();

      expect(container.read(registrationProvider).isSuccess, false);
    });
  });

  group('RegistrationNotifier — submission', () {
    test('successful submit saves under households/{uid}', () async {
      when(() => mockPriority.calculatePriority(
            householdCount: 5,
            vulnerabilityScore: any(named: 'vulnerabilityScore'),
            daysSinceServed: 0,
          )).thenReturn(25);

      when(
        () => mockHouseholdRepo.saveHousehold(
          uid: any(named: 'uid'),
          household: any(named: 'household'),
        ),
      ).thenAnswer((_) async => const Right(unit));
      when(() => mockStorage.setRegistrationComplete(
            householdId: any(named: 'householdId'),
          )).thenAnswer((_) async => {});
      when(() => mockStorage.saveArea(any())).thenAnswer((_) async => {});

      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);

      notifier.setFamilyName('عائلة تجريبية');
      notifier.setArea('الزيتون');
      notifier.setHouseholdSize(5);
      notifier.setHasElderly(value: true);

      await notifier.submit();

      final state = container.read(registrationProvider);
      expect(state.isSuccess, true);
      expect(state.isSubmitting, false);
      expect(state.isEditingExisting, true);

      final captured = verify(
        () => mockHouseholdRepo.saveHousehold(
          uid: captureAny(named: 'uid'),
          household: captureAny(named: 'household'),
        ),
      ).captured;

      expect(captured[0], 'resident-uid-1');
      final household = captured[1] as HouseholdModel;
      expect(household.id, 'resident-uid-1');
      expect(household.familyName, 'عائلة تجريبية');
      expect(household.areaName, 'الزيتون');
      expect(household.householdSize, 5);
      expect(household.hasElderly, true);
      expect(household.priorityScore, 25);

      // The stable uid is what's persisted as the household id — not the
      // area name — so a second submission updates the same record.
      verify(() => mockStorage.setRegistrationComplete(
            householdId: 'resident-uid-1',
          )).called(1);
      verify(() => mockStorage.saveArea('الزيتون')).called(1);
    });

    test('submitting twice reuses the same uid (no duplicate document)',
        () async {
      when(() => mockPriority.calculatePriority(
            householdCount: any(named: 'householdCount'),
            vulnerabilityScore: any(named: 'vulnerabilityScore'),
            daysSinceServed: any(named: 'daysSinceServed'),
          )).thenReturn(10);
      when(
        () => mockHouseholdRepo.saveHousehold(
          uid: any(named: 'uid'),
          household: any(named: 'household'),
        ),
      ).thenAnswer((_) async => const Right(unit));
      when(() => mockStorage.setRegistrationComplete(
            householdId: any(named: 'householdId'),
          )).thenAnswer((_) async => {});
      when(() => mockStorage.saveArea(any())).thenAnswer((_) async => {});

      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);

      notifier.setFamilyName('عائلة تجريبية');
      await notifier.submit();
      notifier.setHouseholdSize(6);
      await notifier.submit();

      final uids = verify(
        () => mockHouseholdRepo.saveHousehold(
          uid: captureAny(named: 'uid'),
          household: any(named: 'household'),
        ),
      ).captured;

      expect(uids, ['resident-uid-1', 'resident-uid-1']);
    });

    test('submit without a signed-in user sets errorMessage', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);

      notifier.setFamilyName('عائلة تجريبية');
      await notifier.submit();

      final state = container.read(registrationProvider);
      expect(state.errorMessage, isNotNull);
      expect(state.isSuccess, false);
      verifyNever(
        () => mockHouseholdRepo.saveHousehold(
          uid: any(named: 'uid'),
          household: any(named: 'household'),
        ),
      );
    });

    test('failure sets errorMessage', () async {
      when(() => mockPriority.calculatePriority(
            householdCount: any(named: 'householdCount'),
            vulnerabilityScore: any(named: 'vulnerabilityScore'),
            daysSinceServed: any(named: 'daysSinceServed'),
          )).thenReturn(10);

      when(
        () => mockHouseholdRepo.saveHousehold(
          uid: any(named: 'uid'),
          household: any(named: 'household'),
        ),
      ).thenAnswer(
        (_) async => const Left(ServerFailure('فشل حفظ البيانات')),
      );

      final container = makeContainer();
      final notifier = container.read(registrationProvider.notifier);

      notifier.setFamilyName('عائلة تجريبية');
      await notifier.submit();

      final state = container.read(registrationProvider);
      expect(state.isSuccess, false);
      expect(state.errorMessage, isNotNull);
      expect(state.isSubmitting, false);
    });
  });
}
