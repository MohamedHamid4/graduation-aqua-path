import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/auth/user_role.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthSource _source;

  AuthRepositoryImpl(this._source);

  @override
  Stream<AppUser?> get authStateChanges => _source.authStateChanges;

  @override
  AppUser? get currentUser => _source.currentUser;

  @override
  Future<Either<Failure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _source.signInWithEmail(
        email: email,
        password: password,
      );
      AppLogger.info('User signed in: ${user.uid}', tag: 'Auth');
      return Right(user);
    } on fb.FirebaseAuthException catch (e) {
      AppLogger.warning(
        'Sign-in failed: ${e.code}',
        tag: 'Auth',
        error: e,
      );
      return Left(AuthFailure(e.code, e.message ?? 'فشل تسجيل الدخول'));
    } catch (e, st) {
      AppLogger.error(
        'Unexpected sign-in error',
        tag: 'Auth',
        error: e,
        stackTrace: st,
      );
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final user = await _source.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      AppLogger.info('User signed up: ${user.uid}', tag: 'Auth');
      return Right(user);
    } on fb.FirebaseAuthException catch (e) {
      AppLogger.warning(
        'Sign-up failed: ${e.code}',
        tag: 'Auth',
        error: e,
      );
      return Left(AuthFailure(e.code, e.message ?? 'فشل إنشاء الحساب'));
    } catch (e, st) {
      AppLogger.error(
        'Unexpected sign-up error',
        tag: 'Auth',
        error: e,
        stackTrace: st,
      );
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> sendPasswordResetEmail(String email) async {
    try {
      await _source.sendPasswordResetEmail(email);
      AppLogger.info('Password reset email sent', tag: 'Auth');
      return const Right(unit);
    } on fb.FirebaseAuthException catch (e) {
      AppLogger.warning(
        'Password reset failed: ${e.code}',
        tag: 'Auth',
        error: e,
      );
      return Left(AuthFailure(e.code, e.message ?? 'فشل إرسال رابط الاستعادة'));
    } catch (e, st) {
      AppLogger.error(
        'Unexpected password-reset error',
        tag: 'Auth',
        error: e,
        stackTrace: st,
      );
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<UserRole?> waitForRoleClaim() async {
    // The claim-setting Cloud Function runs asynchronously right after
    // the resident/driver profile doc is created, so a short bounded
    // retry loop is the correct client-side pattern here — not a single
    // check, and not an unbounded wait.
    const attempts = 6;
    for (var i = 0; i < attempts; i++) {
      final role = await _source.refreshRoleClaim();
      if (role != null) return role;
      if (i < attempts - 1) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
    AppLogger.warning(
      'Role claim not present after $attempts attempts',
      tag: 'Auth',
    );
    return null;
  }

  @override
  Future<UserRole?> getCurrentRole() => _source.getCachedRoleClaim();

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _source.signOut();
      AppLogger.info('User signed out', tag: 'Auth');
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error(
        'Sign-out failed',
        tag: 'Auth',
        error: e,
        stackTrace: st,
      );
      return const Left(UnknownFailure());
    }
  }
}
