import 'package:dartz/dartz.dart';

import '../../../../core/auth/user_role.dart';
import '../../../../core/errors/failures.dart';
import '../entities/app_user.dart';

/// Abstract contract for authentication. The domain and presentation layers
/// depend only on this interface — never on FirebaseAuth directly.
abstract class AuthRepository {
  /// Emits the current user (or `null` when signed out) whenever auth state
  /// changes. This is what the router's redirect logic watches.
  Stream<AppUser?> get authStateChanges;

  /// Returns the currently signed-in user synchronously, if any.
  AppUser? get currentUser;

  Future<Either<Failure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Either<Failure, Unit>> sendPasswordResetEmail(String email);

  Future<Either<Failure, Unit>> signOut();

  /// Polls for up to ~6 seconds (forcing a fresh ID token each attempt)
  /// waiting for the `role` custom claim to appear after sign-up, since
  /// the Cloud Function that sets it runs asynchronously after the
  /// resident/driver profile document is written. Returns `null` if the
  /// claim still hasn't appeared — callers should show a "still setting
  /// up your account" message rather than fail hard in that case.
  Future<UserRole?> waitForRoleClaim();

  /// Reads the `role` claim off the **cached** ID token — no network call,
  /// safe to call on every router redirect (unlike the old
  /// `driverRepo.isDriver(uid)` Firestore read it replaces). May return a
  /// stale/null value for the few seconds right after sign-up before the
  /// claim has propagated; use [waitForRoleClaim] at sign-up time instead.
  Future<UserRole?> getCurrentRole();

  /// Single forced ID-token fetch (bypasses the local cache), returning
  /// whatever `role` claim Firebase actually has right now. Unlike
  /// [waitForRoleClaim] this makes exactly one network round trip instead
  /// of retrying for several seconds — use it when [getCurrentRole]
  /// returns null and the caller needs an authoritative answer before
  /// making a routing decision (e.g. a cold-started session whose locally
  /// persisted token predates a role claim that was already granted).
  Future<UserRole?> refreshRoleClaim();
}
