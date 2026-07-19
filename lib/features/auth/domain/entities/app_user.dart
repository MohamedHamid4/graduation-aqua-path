import 'package:equatable/equatable.dart';

import '../../../../core/auth/user_role.dart';

/// Domain-level representation of an authenticated user.
///
/// Deliberately decoupled from [firebase_auth.User] so the rest of the app
/// never depends on the Firebase SDK type directly — only [AuthRepository]
/// and its Firebase implementation know about the real SDK.
///
/// [role] is read from the Firebase Auth ID token's custom claims (never
/// from a client-writable Firestore field) and may briefly be `null` right
/// after sign-up, before the Cloud Function that sets the claim has run and
/// the client has force-refreshed its token — see
/// `AuthRepository.waitForRoleClaim`.
class AppUser extends Equatable {
  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;
  final UserRole? role;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = false,
    this.role,
  });

  AppUser copyWith({UserRole? role}) => AppUser(
        uid: uid,
        email: email,
        displayName: displayName,
        emailVerified: emailVerified,
        role: role ?? this.role,
      );

  @override
  List<Object?> get props => [uid, email, displayName, emailVerified, role];
}
