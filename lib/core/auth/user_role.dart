/// The three account types AquaPath supports. Backed by a Firebase Auth
/// **custom claim** (`role`), set server-side by Cloud Functions — never
/// trust a client-writable Firestore field for authorization decisions.
///
/// - [resident] and [driver] claims are set automatically by a Firestore
///   trigger the moment the matching `households/{uid}` or `drivers/{uid}`
///   profile document is created (see `functions/src/index.ts`).
/// - [organization] claims are set exclusively by the
///   `createOrganizationUser` callable function, itself only invocable by
///   an existing organization account. There is no self-service path.
enum UserRole {
  resident,
  driver,
  organization;

  static UserRole? fromClaim(String? raw) {
    switch (raw) {
      case 'resident':
        return UserRole.resident;
      case 'driver':
        return UserRole.driver;
      case 'organization':
        return UserRole.organization;
      default:
        return null;
    }
  }

  String get claimValue => name;
}
