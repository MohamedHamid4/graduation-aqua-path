import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:aquapath/core/errors/failures.dart';
import 'package:aquapath/features/auth/domain/entities/app_user.dart';
import 'package:aquapath/features/auth/domain/repositories/auth_repository.dart';
import 'package:aquapath/features/auth/presentation/providers/auth_provider.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _testUser = AppUser(
  uid: 'uid-123',
  email: 'test@aquapath.com',
  displayName: 'Test User',
  emailVerified: true,
);

void main() {
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
    final sl = GetIt.I;
    if (sl.isRegistered<AuthRepository>()) {
      sl.unregister<AuthRepository>();
    }
    sl.registerSingleton<AuthRepository>(mockRepo);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('AuthNotifier — initial state', () {
    test('defaults are correct', () {
      final container = makeContainer();
      final state = container.read(authFormProvider);

      expect(state.isSubmitting, false);
      expect(state.isSuccess, false);
      expect(state.resetEmailSent, false);
      expect(state.errorMessage, isNull);
    });
  });

  group('AuthNotifier — signIn', () {
    test('success sets isSuccess and clears isSubmitting', () async {
      when(() => mockRepo.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => const Right(_testUser));

      final container = makeContainer();
      await container
          .read(authFormProvider.notifier)
          .signIn(email: 'test@aquapath.com', password: '123456');

      final state = container.read(authFormProvider);
      expect(state.isSuccess, true);
      expect(state.isSubmitting, false);
      expect(state.errorMessage, isNull);
    });

    test('failure (wrong-password) sets errorMessage', () async {
      when(() => mockRepo.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer(
        (_) async => const Left(
          AuthFailure('wrong-password', 'كلمة المرور غير صحيحة'),
        ),
      );

      final container = makeContainer();
      await container
          .read(authFormProvider.notifier)
          .signIn(email: 'test@aquapath.com', password: 'wrong');

      final state = container.read(authFormProvider);
      expect(state.isSuccess, false);
      expect(state.errorMessage, 'كلمة المرور غير صحيحة');
    });

    test('trims email before delegating to repository', () async {
      when(() => mockRepo.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => const Right(_testUser));

      final container = makeContainer();
      await container.read(authFormProvider.notifier).signIn(
            email: '  test@aquapath.com  ',
            password: '123456',
          );

      verify(() => mockRepo.signInWithEmail(
            email: 'test@aquapath.com',
            password: '123456',
          )).called(1);
    });
  });

  group('AuthNotifier — signUp', () {
    test('success sets isSuccess', () async {
      when(() => mockRepo.signUpWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
          )).thenAnswer((_) async => const Right(_testUser));

      final container = makeContainer();
      await container.read(authFormProvider.notifier).signUp(
            email: 'new@aquapath.com',
            password: '123456',
            displayName: 'New User',
          );

      expect(container.read(authFormProvider).isSuccess, true);
    });
  });

  group('AuthNotifier — sendPasswordReset', () {
    test('success sets resetEmailSent', () async {
      when(() => mockRepo.sendPasswordResetEmail(any()))
          .thenAnswer((_) async => const Right(unit));

      final container = makeContainer();
      await container
          .read(authFormProvider.notifier)
          .sendPasswordReset('test@aquapath.com');

      final state = container.read(authFormProvider);
      expect(state.resetEmailSent, true);
      expect(state.isSubmitting, false);
    });

    test('failure sets errorMessage', () async {
      when(() => mockRepo.sendPasswordResetEmail(any())).thenAnswer(
        (_) async => const Left(
          AuthFailure('user-not-found', 'لا يوجد حساب بهذا البريد'),
        ),
      );

      final container = makeContainer();
      await container
          .read(authFormProvider.notifier)
          .sendPasswordReset('unknown@aquapath.com');

      expect(container.read(authFormProvider).errorMessage, isNotNull);
      expect(container.read(authFormProvider).resetEmailSent, false);
    });
  });

  group('AuthNotifier — signOut', () {
    test('delegates to repository', () async {
      when(() => mockRepo.signOut()).thenAnswer((_) async => const Right(unit));

      final container = makeContainer();
      await container.read(authFormProvider.notifier).signOut();

      verify(() => mockRepo.signOut()).called(1);
    });
  });

  group('AuthNotifier — consumeSuccess', () {
    test('resets isSuccess and resetEmailSent flags', () async {
      final container = makeContainer();
      final notifier = container.read(authFormProvider.notifier);

      // Manually trigger success state for testing consume
      when(() => mockRepo.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => const Right(_testUser));

      await notifier.signIn(email: 'a@a.com', password: 'p');
      expect(container.read(authFormProvider).isSuccess, true);

      notifier.consumeSuccess();
      expect(container.read(authFormProvider).isSuccess, false);
    });
  });
}
