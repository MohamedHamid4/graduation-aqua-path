import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/auth/user_role.dart';
import '../../domain/entities/app_user.dart';

/// Thin wrapper around [fb.FirebaseAuth] — the only place in the codebase
/// that touches the Firebase Auth SDK directly.
///
/// Role resolution: [authStateChanges] emits a first pass immediately with
/// whatever role is already cached on the current ID token, then re-emits
/// once a fresh token has been fetched — this matters because Firebase
/// caches ID tokens for up to an hour, so a role claim set by a Cloud
/// Function moments ago would otherwise not be visible until the token
/// naturally refreshes.
class FirebaseAuthSource {
  final fb.FirebaseAuth _auth;

  FirebaseAuthSource(this._auth);

  Stream<AppUser?> get authStateChanges =>
      _auth.authStateChanges().asyncMap(_toAppUserWithRole);

  AppUser? get currentUser => _toAppUserSync(_auth.currentUser);

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return (await _toAppUserWithRole(credential.user))!;
  }

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    await credential.user?.reload();
    return (await _toAppUserWithRole(_auth.currentUser))!;
  }

  /// Forces a fresh ID token from Firebase (bypassing the local cache) and
  /// returns the resolved [UserRole], or `null` if no `role` claim has been
  /// set yet. Call this in a short retry loop right after sign-up, while a
  /// Cloud Function is setting the claim asynchronously.
  Future<UserRole?> refreshRoleClaim() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final token = await user.getIdTokenResult(true);
      return UserRole.fromClaim(token.claims?['role'] as String?);
    } catch (e) {
      // Forcing a token refresh requires network. A caller with no
      // connectivity used to get an uncaught FirebaseAuthException here
      // (network-request-failed) that propagated straight through
      // waitForRoleClaim() into whatever awaited it — e.g. the
      // registration success handler, which would then never reach its
      // `isSuccess: true` state update. Treating "couldn't check" the
      // same as "claim not visible yet" (null) is the correct behavior
      // either way: the router's pendingAccountRole fallback already
      // covers a null role gracefully.
      return null;
    }
  }

  /// Cheap, cached-token variant of [refreshRoleClaim] — no network round
  /// trip in the common case. Safe to call on every route redirect.
  Future<UserRole?> getCachedRoleClaim() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final token = await user.getIdTokenResult(false);
      return UserRole.fromClaim(token.claims?['role'] as String?);
    } catch (e) {
      // Called on every router redirect — must never throw, or
      // navigation itself breaks while offline.
      return null;
    }
  }

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() => _auth.signOut();

  Future<AppUser?> _toAppUserWithRole(fb.User? user) async {
    if (user == null) return null;
    UserRole? role;
    try {
      final token = await user.getIdTokenResult();
      role = UserRole.fromClaim(token.claims?['role'] as String?);
    } catch (e) {
      // This drives `authStateChanges`, which is GoRouter's
      // `refreshListenable` — letting a network exception escape here
      // (e.g. app launched offline, or token silently expired mid-trip
      // with no signal) would put the whole auth stream into an error
      // state and break navigation reactivity app-wide, not just role
      // resolution. Falling back to `role: null` instead means the
      // existing pendingAccountRole/isDriver fallbacks in the router
      // handle it the same way they already handle the brief
      // post-signup window before a claim propagates.
      role = null;
    }
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      emailVerified: user.emailVerified,
      role: role,
    );
  }

  AppUser? _toAppUserSync(fb.User? user) {
    if (user == null) return null;
    // Synchronous accessor can't await a fresh token; role is left null
    // here deliberately rather than returning stale data — callers that
    // need role should prefer the async [authStateChanges] stream.
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      emailVerified: user.emailVerified,
    );
  }
}
